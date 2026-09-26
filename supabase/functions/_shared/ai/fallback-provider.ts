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

export interface FallbackAnalysisProviderOptions {
  readonly primary: AnalysisProviderFactory;
  /**
   * `null` when no second provider is configured, in which case the chain is a
   * pass-through and the primary's error surfaces unchanged — bit-for-bit the
   * behaviour before this feature existed.
   */
  readonly fallback: AnalysisProviderFactory | null;
  /** The whole envelope both legs must fit inside, in seconds. */
  readonly totalSeconds: number;
  /** Milliseconds since epoch. Injected so tests need no clock or network. */
  readonly now?: () => number;
}

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

export function createFallbackAnalysisProvider(
  options: FallbackAnalysisProviderOptions,
): AiAnalysisProvider {
  const { primary, fallback, totalSeconds, now = Date.now } = options;

  const primarySeconds = Math.floor(totalSeconds * PRIMARY_SHARE);

  return async (input: AnalysisPromptInput): Promise<ModelAnalysis> => {
    const startedAt = now();

    try {
      // Built here, not above: a provider is bound to one call's budget, and
      // constructing it per request is what keeps the two legs independent.
      return await primary(primarySeconds)(input);
    } catch (thrown) {
      if (!isProviderFault(thrown) || fallback === null) throw thrown;

      // Measured, not assumed. A primary that fails instantly leaves almost the
      // whole envelope; one that burns its share leaves almost none.
      const elapsedSeconds = (now() - startedAt) / 1000;
      const remainingSeconds = Math.floor(totalSeconds - elapsedSeconds);

      if (remainingSeconds < MIN_FALLBACK_SECONDS) throw thrown;

      // The fallback's own failure surfaces as itself. Reporting the primary's
      // error instead would describe a provider that is not the one that
      // ultimately failed, and hide a genuine second outage.
      return await fallback(remainingSeconds)(input);
    }
  };
}
