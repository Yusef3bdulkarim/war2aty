/**
 * F18-T05, rewritten in F20-T10 · The fallback chain.
 *
 * Runs one analysis leg, and on a fallback-eligible failure asks a second one.
 * Both legs are ordinary {@link AnalysisLeg}s built over the same transport,
 * prompt and schema, so the chain itself is pure routing. It holds the order,
 * the request's deadline, the rule for when a second call is warranted, and the
 * one mapping from `ProviderFailure` to the §31 `ApiError` the endpoint throws.
 *
 * ── When it fails over (F20 failure matrix §1, rows A1–A10) ───────────────
 * Only on a `ProviderFailure` whose kind is on the closed allowlist in
 * `provider-failure.ts`: rate limits, upstream outages, network drops, timeouts
 * and unusable output (A1–A5). The chain never fails over on:
 * - a bad key or a malformed request (`auth`, `bad_request`: A6, A7), which are
 *   our deploy faults and must not be hidden behind a second provider;
 * - anything that is not a `ProviderFailure` (A9), which is a bug in our own
 *   code.
 * Config faults (A8) never reach the chain: the legs are built, and their
 * credentials read, before the handler reserves a slot. When both legs fail
 * (A10), the request answers with the second failure's mapping.
 *
 * ── Time (timeout contract §2) ────────────────────────────────────────────
 * One {@link Deadline} for the whole analysis, started when it is called.
 * - Each attempt gets what remains, capped at `attemptCapMs`. The cap only
 *   stops a hung primary from starving the fallback: a primary that fails in
 *   200 ms leaves the fallback nearly the whole budget.
 * - The fallback starts only if at least `minFallbackMs` remains. A second call
 *   with less would almost certainly time out too, turning one failure into two
 *   and a doubled wait. The request then answers the primary's failure (A3:
 *   `TIMEOUT`).
 * Neither attempt can outlive the deadline, so the slot-TTL arithmetic in
 * `analyze-handler.ts` still holds.
 *
 * PRIVACY (§7, §51): the chain never inspects, stores or logs the input or the
 * analysis. It sees an opaque prompt input and an opaque result.
 */

import { ApiError, toApiError } from "../errors/api-error.ts";
import { logEvent } from "../observability/log.ts";
import type { AnalysisPromptInput } from "../prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../schemas/analysis-output.schema.ts";
import { createDeadline, type DeadlineOptions } from "../time/deadline.ts";
import type { AiAnalysisProvider, AnalysisLeg } from "./analysis-provider.ts";
import {
  analysisApiErrorFor,
  isFallbackEligible,
  ProviderFailure,
  type ProviderFailureKind,
} from "./provider-failure.ts";

/**
 * The longest one attempt may run (`AI_ATTEMPT_TIMEOUT_SECONDS`).
 *
 * Set in F20-T09 from the benchmark: Mistral's p95 was 12.7 s and its slowest
 * call 14.7 s, so 18 s lets a normal answer finish while leaving 7 s of the
 * default 25 s budget for Groq when the primary hangs.
 */
export const DEFAULT_ATTEMPT_CAP_MS = 18_000;

/**
 * The least time worth starting a second call with (`MIN_FALLBACK_MS`).
 *
 * Set in F20-T09 from Groq's p95 of 3.1 s, with margin.
 */
export const DEFAULT_MIN_FALLBACK_MS = 5_000;

/** For logs and diagnostics only — never for anything the user sees (§7). */
export type ProviderName = "mistral" | "groq";

export interface FallbackAnalysisProviderOptions {
  readonly primary: AnalysisLeg;
  readonly primaryName: ProviderName;
  /**
   * `null` when no second provider is configured, in which case the chain is a
   * pass-through that only maps the primary's failure onto the wire.
   */
  readonly fallback: AnalysisLeg | null;
  readonly fallbackName: ProviderName | null;
  /** The request's whole budget, both legs included, in seconds. */
  readonly totalSeconds: number;
  /** Per-attempt cap. Defaults to {@link DEFAULT_ATTEMPT_CAP_MS}. */
  readonly attemptCapMs?: number;
  /** Fallback floor. Defaults to {@link DEFAULT_MIN_FALLBACK_MS}. */
  readonly minFallbackMs?: number;
  /** Correlates the `analyze.provider` line with the rest of the request. */
  readonly requestId: string;
  /** Milliseconds since epoch. Injected so tests need no clock or network. */
  readonly now?: () => number;
  /** Injected so tests can see each attempt's budget without a real timer. */
  readonly timeoutSignal?: DeadlineOptions["timeoutSignal"];
  /** Injected so tests can read the event without capturing stdout. */
  readonly log?: typeof logEvent;
}

/** Why a failed primary did not reach the fallback. */
type FailoverSkipped =
  /** Single-leg deployment. */
  | "no_fallback_configured"
  /** A config fault, a programmer fault, or anything off the allowlist. */
  | "not_fallback_eligible"
  /** Less than `minFallbackMs` of the deadline left. */
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
    attemptCapMs = DEFAULT_ATTEMPT_CAP_MS,
    minFallbackMs = DEFAULT_MIN_FALLBACK_MS,
    requestId,
    now = Date.now,
    timeoutSignal,
    log = logEvent,
  } = options;

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
   * - `primary_failure` and `failure` carry the `ProviderFailure` kind: the
   *   primary's, and the one the request ended on.
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
    // Started per call: the chain is built per request, but the clock runs
    // from the moment there is an analysis to do.
    const deadline = createDeadline(totalSeconds * 1000, { now, timeoutSignal });

    let served: ModelAnalysis;
    try {
      served = await primary(input, deadline.signal(attemptCapMs));
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
      // whole budget; one that hits its cap leaves only what the cap spared.
      if (deadline.remainingMs() < minFallbackMs) {
        throw noFailover("insufficient_budget");
      }

      // `fallbackName` is always set alongside `fallback` by the caller; the
      // coalesce keeps the types honest without asserting.
      const secondName = fallbackName ?? primaryName;

      let fallbackServed: ModelAnalysis;
      try {
        fallbackServed = await fallback(input, deadline.signal(attemptCapMs));
      } catch (fallbackThrown) {
        // The fallback's own failure surfaces as itself (A10). Reporting the
        // primary's error instead would describe a provider that is not the one
        // that ultimately failed, and hide a genuine second outage.
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
