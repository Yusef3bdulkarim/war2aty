/**
 * F18-T05, rewritten in F20-T10, generalised in F36-T06 · The analysis chain.
 *
 * Runs one analysis leg, and on a fallback-eligible failure asks a second one.
 * Both legs are ordinary {@link AnalysisLeg}s built over the same transport,
 * prompt and schema, so this file is pure wiring: it names the two legs, says
 * the analysis stage's log event and its §31 mapping, and hands the rest to
 * {@link createLegChain}.
 *
 * ── Why this file still exists ────────────────────────────────────────────
 * F36 needs three legs on the reading side and three on the explaining side,
 * so the chain's arity moved into `leg-chain.ts`. `analyze-document` is frozen
 * until 1.0.x is out of support (F36's scope fence), so it keeps calling the
 * two-leg shape it has always called, with its tests unedited as the proof
 * that the generalisation changed nothing underneath it.
 *
 * The routing rules, the time budget and the one log line are all documented
 * in `leg-chain.ts`. Nothing about them is specific to the analysis stage
 * except the two values this file supplies:
 * - the event name `analyze.provider`, which F18-T07 put in the log explorer;
 * - `analysisApiErrorFor`, the §31 mapping for an analysis failure.
 *
 * PRIVACY (§7, §51): the chain never inspects, stores or logs the input or the
 * analysis. It sees an opaque prompt input and an opaque result.
 */

import { logEvent } from "../observability/log.ts";
import type { AnalysisPromptInput } from "../prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../schemas/analysis-output.schema.ts";
import type { DeadlineOptions } from "../time/deadline.ts";
import type { AiAnalysisProvider, AnalysisLeg } from "./analysis-provider.ts";
import { type ChainLeg, createLegChain, type ProviderName } from "./leg-chain.ts";
import { analysisApiErrorFor } from "./provider-failure.ts";

/**
 * The timing defaults live with the chain that applies them. Re-exported here
 * because `chain-timing.ts` and the analysis tests have always read them from
 * this module, and F36-T06 is a refactor that must not move anything the
 * frozen `analyze-document` path depends on.
 */
export { DEFAULT_ATTEMPT_CAP_MS, DEFAULT_MIN_FALLBACK_MS } from "./leg-chain.ts";

export type { ProviderName };

/** The log event the analysis stage has emitted since F18-T07. */
const ANALYZE_PROVIDER_EVENT = "analyze.provider";

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
  /** Per-attempt cap. Defaults to `DEFAULT_ATTEMPT_CAP_MS`. */
  readonly attemptCapMs?: number;
  /** Fallback floor. Defaults to `DEFAULT_MIN_FALLBACK_MS`. */
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

export function createFallbackAnalysisProvider(
  options: FallbackAnalysisProviderOptions,
): AiAnalysisProvider {
  const { primary, primaryName, fallback, fallbackName, ...timing } = options;

  const legs: ChainLeg<AnalysisPromptInput, ModelAnalysis>[] = [
    { name: primaryName, run: primary },
  ];
  if (fallback !== null) {
    // `fallbackName` is always set alongside `fallback` by the caller; the
    // coalesce keeps the types honest without asserting.
    legs.push({ name: fallbackName ?? primaryName, run: fallback });
  }

  return createLegChain<AnalysisPromptInput, ModelAnalysis>({
    legs,
    event: ANALYZE_PROVIDER_EVENT,
    apiErrorFor: analysisApiErrorFor,
    ...timing,
  });
}
