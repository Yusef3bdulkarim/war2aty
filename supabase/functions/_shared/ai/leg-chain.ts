/**
 * F36-T06 · The leg chain — N provider attempts behind one time budget.
 *
 * F18 built a chain of exactly two legs for `analyze-document`, and F20
 * rewrote its timing but kept the arity: `primary` and `fallback`, nothing
 * else. F36 needs three legs on the reading side (T07) and three on the
 * explaining side (T11), so the arity had to go. Everything else about that
 * chain was right and is kept here verbatim: one deadline for the whole
 * request, a per-attempt cap, a floor below which a further call is not worth
 * starting, and the closed allowlist that decides whether a failure may be
 * retried at all.
 *
 * `fallback-provider.ts` is now a two-leg caller of this module, so
 * `analyze-document` runs on exactly the behaviour it ran on before — see that
 * file's header and its unedited tests, which are this refactor's proof.
 *
 * ── When it moves to the next leg (F20 failure matrix §1, rows A1–A10) ────
 * Only on a `ProviderFailure` whose kind is on the closed allowlist in
 * `provider-failure.ts`: rate limits, upstream outages, network drops, timeouts
 * and unusable output (A1–A5). The chain never moves on from:
 * - a bad key or a malformed request (`auth`, `bad_request`: A6, A7), which are
 *   our deploy faults and must not be hidden behind a second provider;
 * - anything that is not a `ProviderFailure` (A9), which is a bug in our own
 *   code.
 * Config faults (A8) never reach the chain: the legs are built, and their
 * credentials read, before the handler reserves a slot. When the last leg fails
 * (A10), the request answers with THAT leg's mapping, not the first one's.
 *
 * ── Time (timeout contract §2) ────────────────────────────────────────────
 * One {@link Deadline} for the whole stage, started when the chain is called.
 * - Each attempt gets what remains, capped at `attemptCapMs`. The cap only
 *   stops a hung leg from starving the ones behind it: a leg that fails in
 *   200 ms leaves the next one nearly the whole budget.
 * - A further leg starts only if at least `minFallbackMs` remains. A call with
 *   less would almost certainly time out too, turning one failure into two and
 *   a doubled wait. The request then answers the failure it stopped on (A3:
 *   `TIMEOUT`).
 * No combination of attempts can outlive the deadline, however many legs there
 * are, so the slot-TTL arithmetic in the handlers still holds.
 *
 * PRIVACY (§7, §51): the chain never inspects, stores or logs the input or the
 * result. It sees an opaque input and an opaque answer, and is generic over
 * both precisely so it cannot reach into either.
 */

import { ApiError, toApiError } from "../errors/api-error.ts";
import { logEvent } from "../observability/log.ts";
import { createDeadline, type DeadlineOptions } from "../time/deadline.ts";
import {
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
 * The least time worth starting a further call with (`MIN_FALLBACK_MS`).
 *
 * Set in F20-T09 from Groq's p95 of 3.1 s, with margin.
 */
export const DEFAULT_MIN_FALLBACK_MS = 5_000;

/**
 * For logs and diagnostics only — never for anything the user sees (§7).
 *
 * The three reading names are chain POSITIONS, not model ids. D1-bis settled
 * the reading chain as three Gemini ids on one key — three quota buckets, one
 * provider — and T08 makes those ids operator-settable without a deploy, so a
 * name tied to an id would go stale the first time an operator moved one. The
 * position is what the log is actually asked about: leg 3 answering means the
 * two buckets in front of it are spent.
 */
export type ProviderName =
  | "mistral"
  | "groq"
  | "gemini_read_1"
  | "gemini_read_2"
  | "gemini_read_3";

/**
 * One provider, one attempt, plus the name its outcome is logged under.
 *
 * `run` throws only `ProviderFailure`. `signal` bounds the attempt and comes
 * from the chain's `Deadline`, so no leg decides its own timeout.
 */
export interface ChainLeg<TInput, TResult> {
  readonly name: ProviderName;
  readonly run: (input: TInput, signal: AbortSignal) => Promise<TResult>;
}

export interface LegChainOptions<TInput, TResult> {
  /**
   * Tried in order, first to last. One leg is a legal chain: it then maps its
   * own failure onto the wire and nothing else.
   */
  readonly legs: readonly ChainLeg<TInput, TResult>[];
  /** The stage's whole budget, every leg included, in seconds. */
  readonly totalSeconds: number;
  /** Per-attempt cap. Defaults to {@link DEFAULT_ATTEMPT_CAP_MS}. */
  readonly attemptCapMs?: number;
  /** Floor for starting a further leg. Defaults to {@link DEFAULT_MIN_FALLBACK_MS}. */
  readonly minFallbackMs?: number;
  /** Correlates the chain's one log line with the rest of the request. */
  readonly requestId: string;
  /**
   * The log event name, e.g. `analyze.provider`. Each stage owns its own, so
   * two chains in one request stay tellable apart in the log explorer.
   */
  readonly event: string;
  /**
   * How a `ProviderFailure` becomes the §31 error the endpoint throws —
   * `analysisApiErrorFor`, `ocrApiErrorFor`, or whatever the stage's own
   * mapping table says. Deliberately not defaulted: the mapping decides what
   * the app is told it may do next, which is never a detail to inherit.
   */
  readonly apiErrorFor: (failure: ProviderFailure) => ApiError;
  /** Milliseconds since epoch. Injected so tests need no clock or network. */
  readonly now?: () => number;
  /** Injected so tests can see each attempt's budget without a real timer. */
  readonly timeoutSignal?: DeadlineOptions["timeoutSignal"];
  /** Injected so tests can read the event without capturing stdout. */
  readonly log?: typeof logEvent;
}

/** Why a failed leg was not followed by another one. */
export type FailoverSkipped =
  /** The chain had no further leg. */
  | "no_fallback_configured"
  /** A config fault, a programmer fault, or anything off the allowlist. */
  | "not_fallback_eligible"
  /** Less than `minFallbackMs` of the deadline left. */
  | "insufficient_budget";

/** The failure kind, or `null` for anything that is not a `ProviderFailure`. */
function kindOf(thrown: unknown): ProviderFailureKind | null {
  return thrown instanceof ProviderFailure ? thrown.kind : null;
}

export function createLegChain<TInput, TResult>(
  options: LegChainOptions<TInput, TResult>,
): (input: TInput) => Promise<TResult> {
  const {
    legs,
    totalSeconds,
    attemptCapMs = DEFAULT_ATTEMPT_CAP_MS,
    minFallbackMs = DEFAULT_MIN_FALLBACK_MS,
    requestId,
    event,
    apiErrorFor,
    now = Date.now,
    timeoutSignal,
    log = logEvent,
  } = options;

  if (legs.length === 0) {
    // A programmer error, not a runtime condition: the legs are built from
    // config at deploy time, never from the request.
    throw new RangeError("A leg chain needs at least one leg.");
  }

  /**
   * The §31 error to throw for whatever a leg threw.
   *
   * A `ProviderFailure` goes through the stage's mapping. Anything else is our
   * own bug and surfaces as a generic INTERNAL_ERROR with its message
   * discarded, exactly as the endpoint boundary would have treated it.
   */
  const wireErrorFor = (thrown: unknown): ApiError =>
    thrown instanceof ProviderFailure ? apiErrorFor(thrown) : toApiError(thrown);

  /**
   * Emits exactly one line per stage (F18-T07), on every path.
   *
   * On free tiers this is the only way to see how often 429s are pushing
   * traffic down the chain, which is the signal that the day's capacity has
   * run out.
   * - `provider` is whoever ANSWERED, or the last leg attempted when the stage
   *   failed.
   * - `failed_over` is whether any leg but the first was reached.
   * - `primary_failure` is the FIRST leg's failure kind, and `failure` the kind
   *   the stage ended on. In a chain of three the middle leg's kind is not on
   *   the line: the field set is fixed, and `provider` already says how far the
   *   chain got, which is what the quota question needs.
   * - `error_code` is the §31 code the request ended with, and is present only
   *   on failure.
   *
   * PRIVACY (§7, §51): provider names, failure kinds, §31 codes and booleans
   * only. Naming a provider is forbidden in USER-FACING copy, not in server
   * logs, and nothing here touches the document, the prompt or the answer.
   */
  const report = (fields: {
    provider: ProviderName;
    failedOver: boolean;
    primaryFailure?: ProviderFailureKind | null;
    failure?: ProviderFailureKind | null;
    errorCode?: string;
    failoverSkipped?: FailoverSkipped;
  }): void => {
    log(event, {
      request_id: requestId,
      provider: fields.provider,
      failed_over: fields.failedOver,
      primary_failure: fields.primaryFailure ?? undefined,
      failure: fields.failure ?? undefined,
      error_code: fields.errorCode,
      failover_skipped: fields.failoverSkipped,
    });
  };

  return async (input: TInput): Promise<TResult> => {
    // Started per call: the chain is built before the slot is reserved, but the
    // clock runs from the moment there is work to do.
    const deadline = createDeadline(totalSeconds * 1000, { now, timeoutSignal });

    /** The first leg's kind, which the line reports as `primary_failure`. */
    let firstFailure: ProviderFailureKind | null | undefined;

    for (let index = 0; index < legs.length; index++) {
      const leg = legs[index];
      const failedOver = index > 0;
      const isLast = index === legs.length - 1;

      // Declared outside the `try` so that reporting a SUCCESS cannot land in
      // the catch below and be classified as this leg failing.
      let served: TResult;
      try {
        served = await leg.run(input, deadline.signal(attemptCapMs));
      } catch (thrown) {
        const failure = kindOf(thrown);
        if (index === 0) firstFailure = failure;

        /**
         * Why the chain stops here, or `null` to try the next leg.
         *
         * The order matters and is F20's: eligibility first, because a deploy
         * fault must be seen rather than papered over by another provider;
         * then whether a leg is even left; then whether enough of the deadline
         * remains for it to be worth calling. Each is measured, not assumed.
         */
        const stopReason = (): FailoverSkipped | null => {
          if (failure === null || !isFallbackEligible(failure)) return "not_fallback_eligible";
          if (isLast) return "no_fallback_configured";
          if (deadline.remainingMs() < minFallbackMs) return "insufficient_budget";
          return null;
        };

        const reason = stopReason();
        if (reason === null) continue;

        const wire = wireErrorFor(thrown);
        report({
          provider: leg.name,
          failedOver,
          primaryFailure: firstFailure,
          failure,
          errorCode: wire.code,
          // A chain that failed over and then ran out of legs has already said
          // so with `failed_over` and `failure`; repeating it as
          // "no_fallback_configured" would name a fallback that did exist and
          // did run. The field answers why a leg was not FOLLOWED by another,
          // so it is omitted exactly where there was never another to expect.
          failoverSkipped: failedOver && isLast ? undefined : reason,
        });
        throw wire;
      }

      report({ provider: leg.name, failedOver, primaryFailure: firstFailure });
      return served;
    }

    // Unreachable: every iteration either returns or throws, and the chain is
    // never empty. Present so the function is total rather than relying on the
    // compiler's flow analysis holding after a future edit.
    throw new RangeError("A leg chain needs at least one leg.");
  };
}
