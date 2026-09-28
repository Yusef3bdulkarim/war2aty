/**
 * F18-T05, revised in F20-T04 · The fallback chain.
 *
 * Runs one analysis leg, and on a fallback-eligible failure asks a second one.
 * Both legs are ordinary {@link AnalysisLeg}s built over the same transport,
 * prompt and schema, so the chain itself is pure routing. It holds the order,
 * the time budget, the rule for when a second call is warranted, and the one
 * mapping from `ProviderFailure` to the §31 `ApiError` the endpoint throws.
 *
 * ── When it fails over (F20 failure matrix §1) ────────────────────────────
 * Only on a `ProviderFailure` whose kind is on the closed allowlist in
 * `provider-failure.ts`: rate limits, upstream outages, network drops, timeouts
 * with enough budget left, and unusable output. The chain never fails over on:
 * - a bad key or a malformed request (`auth`, `bad_request`), which are our
 *   deploy faults and must not be hidden behind a second provider;
 * - anything that is not a `ProviderFailure`, which is a bug in our own code.
 *
 * ── Time (interim until F20-T10) ──────────────────────────────────────────
 * The budget is still F18's up-front split: the primary gets
 * {@link PRIMARY_SHARE} of the whole, and the fallback gets whatever genuinely
 * remains. F20-T10 replaces this with the single `Deadline` of timeout
 * contract §2. Until then there is only ever one leg (the Mistral leg arrives
 * in F20-T11), so the split is never exercised in production.
 *
 * PRIVACY (§7, §51): the chain never inspects, stores or logs the input or the
 * analysis. It sees an opaque prompt input and an opaque result.
 */

import { ApiError, toApiError } from "../errors/api-error.ts";
import { logEvent } from "../observability/log.ts";
import type { AnalysisPromptInput } from "../prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../schemas/analysis-output.schema.ts";
import type { AiAnalysisProvider } from "./analysis-provider.ts";
import {
  analysisApiErrorFor,
  isFallbackEligible,
  ProviderFailure,
  type ProviderFailureKind,
} from "./provider-failure.ts";

/**
 * The primary's share of the total budget.
 *
 * Not 0.5: the primary is expected to serve nearly every request, so it gets
 * the larger half, and the fallback is sized by what actually remains rather
 * than by this fraction. At the default 25s that is 15s for the primary.
 */
export const PRIMARY_SHARE = 0.6;

/**
 * The least time worth starting a second call with.
 *
 * Below this the fallback would almost certainly time out too, turning one
 * failure into two and making the user wait the whole budget to learn it.
 */
export const MIN_FALLBACK_SECONDS = 8;

/**
 * One leg bound to a per-call budget in seconds, throwing only
 * `ProviderFailure`. The caller builds it over an `AnalysisLeg` and a signal.
 */
export type BudgetedLeg = (
  seconds: number,
) => (input: AnalysisPromptInput) => Promise<ModelAnalysis>;

/** For logs and diagnostics only — never for anything the user sees (§7). */
export type ProviderName = "mistral" | "groq";

export interface FallbackAnalysisProviderOptions {
  readonly primary: BudgetedLeg;
  readonly primaryName: ProviderName;
  /**
   * `null` when no second provider is configured, in which case the chain is a
   * pass-through that only maps the primary's failure onto the wire.
   */
  readonly fallback: BudgetedLeg | null;
  readonly fallbackName: ProviderName | null;
  /** The whole envelope both legs must fit inside, in seconds. */
  readonly totalSeconds: number;
  /** Correlates the `analyze.provider` line with the rest of the request. */
  readonly requestId: string;
  /** Milliseconds since epoch. Injected so tests need no clock or network. */
  readonly now?: () => number;
  /** Injected so tests can read the event without capturing stdout. */
  readonly log?: typeof logEvent;
}

/** Why a failed primary did not reach the fallback. */
type FailoverSkipped =
  /** Single-leg deployment. */
  | "no_fallback_configured"
  /** A config fault, a programmer fault, or anything off the allowlist. */
  | "not_fallback_eligible"
  /** Too little of the envelope left for a second call to stand a chance. */
  | "insufficient_budget";

/** The failure kind, or `null` for anything that is not a `ProviderFailure`. */
function kindOf(thrown: unknown): ProviderFailureKind | null {
  return thrown instanceof ProviderFailure ? thrown.kind : null;
}

/**
 * The §31 error to throw for whatever a leg threw.
 *
 * A `ProviderFailure` goes through the matrix mapping. Anything else is our own
 * bug and surfaces as a generic INTERNAL_ERROR with its message discarded,
 * exactly as the endpoint boundary would have treated it.
 */
function wireErrorFor(thrown: unknown): ApiError {
  return thrown instanceof ProviderFailure ? analysisApiErrorFor(thrown) : toApiError(thrown);
}

export function createFallbackAnalysisProvider(
  options: FallbackAnalysisProviderOptions,
): AiAnalysisProvider {
  const {
    primary,
    primaryName,
    fallback,
    fallbackName,
    totalSeconds,
    requestId,
    now = Date.now,
    log = logEvent,
  } = options;

  const primarySeconds = Math.floor(totalSeconds * PRIMARY_SHARE);

  /**
   * Emits exactly one `analyze.provider` line per analysis (F18-T07).
   *
   * On free tiers this is the only way to see how often 429s are pushing
   * traffic to the fallback, which is the signal that the day's capacity has
   * run out.
   * - `provider` is whoever ANSWERED, or the last one attempted when the
   *   analysis failed.
   * - `error_code` is the §31 code the request ended with, and is present
   *   only on failure.
   * - The `*_failure` fields carry the `ProviderFailure` kind that caused it.
   *
   * PRIVACY (§7, §51): provider names, failure kinds, §31 codes and booleans
   * only. Naming a provider is forbidden in USER-FACING copy, not in server
   * logs, and nothing here touches the document, the prompt or the analysis.
   */
  const report = (fields: {
    provider: ProviderName;
    failedOver: boolean;
    primaryFailure?: ProviderFailureKind | null;
    failure?: ProviderFailureKind | null;
    errorCode?: string;
    failoverSkipped?: FailoverSkipped;
  }): void => {
    log("analyze.provider", {
      request_id: requestId,
      provider: fields.provider,
      failed_over: fields.failedOver,
      primary_failure: fields.primaryFailure ?? undefined,
      failure: fields.failure ?? undefined,
      error_code: fields.errorCode,
      failover_skipped: fields.failoverSkipped,
    });
  };

  return async (input: AnalysisPromptInput): Promise<ModelAnalysis> => {
    const startedAt = now();

    let served: ModelAnalysis;
    try {
      // Built here, not above: a leg is bound to one call's budget, and
      // constructing it per request is what keeps the two legs independent.
      served = await primary(primarySeconds)(input);
    } catch (thrown) {
      const primaryFailure = kindOf(thrown);

      /**
       * Records why no second call was made and returns the primary's wire
       * error for the caller to throw.
       *
       * Returns rather than throws so the `throw` stays visible at each call
       * site, which is also what lets the compiler narrow `fallback` below.
       */
      const noFailover = (failoverSkipped: FailoverSkipped): ApiError => {
        const wire = wireErrorFor(thrown);
        report({
          provider: primaryName,
          failedOver: false,
          primaryFailure,
          failure: primaryFailure,
          errorCode: wire.code,
          failoverSkipped,
        });
        return wire;
      };

      if (primaryFailure === null || !isFallbackEligible(primaryFailure)) {
        throw noFailover("not_fallback_eligible");
      }
      if (fallback === null) throw noFailover("no_fallback_configured");

      // Measured, not assumed. A primary that fails instantly leaves almost the
      // whole envelope; one that burns its share leaves almost none.
      const elapsedSeconds = (now() - startedAt) / 1000;
      const remainingSeconds = Math.floor(totalSeconds - elapsedSeconds);

      if (remainingSeconds < MIN_FALLBACK_SECONDS) {
        throw noFailover("insufficient_budget");
      }

      // `fallbackName` is always set alongside `fallback` by the caller; the
      // coalesce keeps the types honest without asserting.
      const secondName = fallbackName ?? primaryName;

      let fallbackServed: ModelAnalysis;
      try {
        fallbackServed = await fallback(remainingSeconds)(input);
      } catch (fallbackThrown) {
        // The fallback's own failure surfaces as itself. Reporting the primary's
        // error instead would describe a provider that is not the one that
        // ultimately failed, and hide a genuine second outage.
        const wire = wireErrorFor(fallbackThrown);
        report({
          provider: secondName,
          failedOver: true,
          primaryFailure,
          failure: kindOf(fallbackThrown),
          errorCode: wire.code,
        });
        throw wire;
      }

      report({ provider: secondName, failedOver: true, primaryFailure });
      return fallbackServed;
    }

    report({ provider: primaryName, failedOver: false });
    return served;
  };
}
