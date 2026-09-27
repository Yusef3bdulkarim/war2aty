/**
 * F18-T05 · The fallback chain.
 *
 * Runs one analysis provider, and on a *transport* failure asks a second one.
 * Both legs are ordinary {@link AiAnalysisProvider}s built over the same
 * transport, prompt and schema, so the chain itself is pure routing: it holds
 * the order, the time budget, and the rule for when a second call is warranted.
 *
 * ── Why only transport failures (F18 decision 4) ──────────────────────────
 * A provider that does not answer — 429, 5xx, a dropped connection, a timeout —
 * tells us nothing about the document, so another provider may well succeed.
 * A provider that answers with unusable JSON has made a considered judgement
 * about a damaged or unreadable page, and the other model will usually reach
 * the same conclusion; a second full call would double the user's wait to
 * confirm it. `ApiError.providerFault` is what separates the two, and
 * `assertModelAnalysis` already catches the latter.
 *
 * On free tiers 429 is the common trigger, which is the point: the chain is
 * what turns "today's Gemini quota is spent" into "served by Groq instead"
 * rather than an outage.
 *
 * ── Why the budget is split, not doubled ──────────────────────────────────
 * The whole chain must fit inside the caller's existing `aiTimeoutSeconds`, so
 * the slot-TTL arithmetic in `analyze-handler.ts`
 * (`aiTimeoutSeconds + RESERVATION_GRACE_SECONDS`) stays correct and no user
 * waits longer than they do today. There is no client-side timeout in the app;
 * this budget is the only gate.
 *
 * PRIVACY (§7, §51): the chain never inspects, stores or logs the input or the
 * analysis. It sees an opaque prompt input and an opaque result.
 */

import { ApiError } from "../errors/api-error.ts";
import { logEvent } from "../observability/log.ts";
import type { AnalysisPromptInput } from "../prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../schemas/analysis-output.schema.ts";
import type { AiAnalysisProvider } from "./analysis-provider.ts";

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
 * failure into two and making the user wait the whole budget to learn it. The
 * practical effect: a primary that *times out* consumes its share and leaves
 * too little, so a timeout does not trigger a doomed second call — while a
 * primary that 429s in 200ms leaves ~24.8s and does.
 */
export const MIN_FALLBACK_SECONDS = 8;

/** Builds a provider bound to a per-call second budget. */
export type AnalysisProviderFactory = (seconds: number) => AiAnalysisProvider;

/** For logs and diagnostics only — never for anything the user sees (§7). */
export type ProviderName = "groq" | "gemini";

export interface ProviderOrder<T> {
  readonly primary: T;
  readonly primaryName: ProviderName;
  /** `null` when only one provider is configured. */
  readonly fallback: T | null;
  readonly fallbackName: ProviderName | null;
}

/**
 * The F18 provider matrix, as a pure function (F18-T06).
 *
 * | `geminiPrimary` | Gemini configured | primary | fallback |
 * |---|---|---|---|
 * | false | no  | groq   | none — *identical to pre-F18 behaviour* |
 * | false | yes | groq   | gemini — *Groq's quota goes first, Gemini takes the overflow* |
 * | true  | yes | gemini | groq |
 * | true  | no  | groq   | none — *a config error; the caller logs it* |
 *
 * Generic over the leg type so the matrix can be tested without building HTTP
 * clients, and so the caller keeps its legs type-safe with no null assertions.
 * The flag chooses the ORDER; whether a second leg exists at all is decided by
 * whether Gemini is configured.
 */
export function resolveProviderOrder<T>(
  options: {
    readonly geminiPrimary: boolean;
    readonly groq: T;
    readonly gemini: T | null;
  },
): ProviderOrder<T> {
  const { geminiPrimary, groq, gemini } = options;

  if (geminiPrimary && gemini !== null) {
    return {
      primary: gemini,
      primaryName: "gemini",
      fallback: groq,
      fallbackName: "groq",
    };
  }

  // Groq leads in every remaining case, including the misconfigured one — a
  // flag flipped without a key must degrade to today's behaviour, not to an
  // outage. The caller is responsible for making that state loud.
  return {
    primary: groq,
    primaryName: "groq",
    fallback: gemini,
    fallbackName: gemini === null ? null : "gemini",
  };
}

export interface FallbackAnalysisProviderOptions {
  readonly primary: AnalysisProviderFactory;
  readonly primaryName: ProviderName;
  /**
   * `null` when no second provider is configured, in which case the chain is a
   * pass-through and the primary's error surfaces unchanged — bit-for-bit the
   * behaviour before this feature existed.
   */
  readonly fallback: AnalysisProviderFactory | null;
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

/** Why a provider fault did not reach the fallback. */
type FailoverSkipped =
  /** Single-leg deployment — the default, and not a fault. */
  | "no_fallback_configured"
  /** The primary answered; the answer was unusable (F18 decision 4). */
  | "not_provider_fault"
  /** Too little of the envelope left for a second call to stand a chance. */
  | "insufficient_budget";

/**
 * Whether `thrown` is a provider declining to answer, rather than answering
 * badly or any other failure.
 *
 * Anything that is not an `ApiError` is a bug in our own code, not a provider
 * fault, and must surface as itself rather than being retried against a second
 * provider.
 */
function isProviderFault(thrown: unknown): boolean {
  return thrown instanceof ApiError && thrown.providerFault;
}

/** The §31 code of an error, or `null` when it is not one of ours. */
function codeOf(thrown: unknown): string | null {
  return thrown instanceof ApiError ? thrown.code : null;
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
   * run out. `provider` is whoever ANSWERED, or the last one attempted when the
   * analysis failed; `error_code` is what separates those two cases.
   *
   * PRIVACY (§7, §51): provider names, §31 error codes and booleans only.
   * Naming a provider is forbidden in USER-FACING copy, not in server logs, and
   * nothing here touches the document, the prompt or the analysis.
   */
  const report = (fields: {
    provider: ProviderName;
    failedOver: boolean;
    primaryErrorCode?: string | null;
    errorCode?: string | null;
    failoverSkipped?: FailoverSkipped;
  }): void => {
    log("analyze.provider", {
      request_id: requestId,
      provider: fields.provider,
      failed_over: fields.failedOver,
      primary_error_code: fields.primaryErrorCode ?? undefined,
      error_code: fields.errorCode ?? undefined,
      failover_skipped: fields.failoverSkipped,
    });
  };

  return async (input: AnalysisPromptInput): Promise<ModelAnalysis> => {
    const startedAt = now();

    let served: ModelAnalysis;
    try {
      // Built here, not above: a provider is bound to one call's budget, and
      // constructing it per request is what keeps the two legs independent.
      served = await primary(primarySeconds)(input);
    } catch (thrown) {
      const primaryErrorCode = codeOf(thrown);

      /**
       * Records why no second call was made and hands back the primary's error
       * for the caller to throw.
       *
       * Returns rather than throws so the `throw` stays visible at each call
       * site, which is also what lets the compiler narrow `fallback` below.
       */
      const noFailover = (failoverSkipped: FailoverSkipped): unknown => {
        report({
          provider: primaryName,
          failedOver: false,
          primaryErrorCode,
          errorCode: primaryErrorCode,
          failoverSkipped,
        });
        return thrown;
      };

      // The answer was unusable rather than absent: the model's judgement about
      // a damaged page, which a second model will usually share.
      if (!isProviderFault(thrown)) throw noFailover("not_provider_fault");
      // Single-leg deployment — the default, and not a fault.
      if (fallback === null) throw noFailover("no_fallback_configured");

      // Measured, not assumed. A primary that fails instantly leaves almost the
      // whole envelope; one that burns its share leaves almost none.
      const elapsedSeconds = (now() - startedAt) / 1000;
      const remainingSeconds = Math.floor(totalSeconds - elapsedSeconds);

      if (remainingSeconds < MIN_FALLBACK_SECONDS) {
        throw noFailover("insufficient_budget");
      }

      // `fallbackName` is non-null whenever `fallback` is, by construction in
      // `resolveProviderOrder`; the coalesce keeps the types honest without
      // asserting.
      const secondName = fallbackName ?? primaryName;

      let fallbackServed: ModelAnalysis;
      try {
        fallbackServed = await fallback(remainingSeconds)(input);
      } catch (fallbackThrown) {
        // The fallback's own failure surfaces as itself. Reporting the primary's
        // error instead would describe a provider that is not the one that
        // ultimately failed, and hide a genuine second outage.
        report({
          provider: secondName,
          failedOver: true,
          primaryErrorCode,
          errorCode: codeOf(fallbackThrown),
        });
        throw fallbackThrown;
      }

      report({ provider: secondName, failedOver: true, primaryErrorCode });
      return fallbackServed;
    }

    report({ provider: primaryName, failedOver: false });
    return served;
  };
}
