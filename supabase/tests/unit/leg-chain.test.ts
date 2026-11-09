/**
 * F36-T06 · Tests for the generalised leg chain.
 *
 * `fallback-provider.test.ts` already pins every two-leg rule, unedited, and
 * that file is the proof the generalisation changed nothing for
 * `analyze-document`. This file covers only what two legs cannot express: a
 * chain of three, and the boundaries that only appear once there is a leg
 * behind the fallback.
 *
 * The chain is driven over `string → string` rather than over an analysis.
 * That is the point: the chain is generic precisely so it cannot reach into
 * the input or the answer, and a test that handed it a `ModelAnalysis` would
 * quietly suggest otherwise.
 *
 * Entirely offline: every leg is a fake, the clock is injected, and so is the
 * timer behind each attempt's signal, which is how the tests read every budget
 * the chain hands out without waiting on real time.
 */

import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  type ChainLeg,
  createLegChain,
  DEFAULT_ATTEMPT_CAP_MS,
  DEFAULT_MIN_FALLBACK_MS,
  type LegChainOptions,
  type ProviderName,
} from "../../functions/_shared/ai/leg-chain.ts";
import {
  analysisApiErrorFor,
  ProviderFailure,
} from "../../functions/_shared/ai/provider-failure.ts";

const INPUT = "فاتورة كهرباء بمبلغ 850 جنيه";
const TOTAL_SECONDS = 25;
const REQUEST_ID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";
const EVENT = "explain.provider";

/** The three reading positions D1-bis settled on, used here as any three legs. */
const NAMES: readonly ProviderName[] = ["gemini_read_1", "gemini_read_2", "gemini_read_3"];

/** Fallback-eligible failures (matrix rows A1–A5). */
const RATE_LIMITED = new ProviderFailure("rate_limited");
const SERVER_ERROR = new ProviderFailure("upstream_unavailable");
const PROVIDER_TIMEOUT = new ProviderFailure("timeout");

/** Our own faults, never retried against a further leg (A6, A7). */
const BAD_KEY = new ProviderFailure("auth");

// ── fakes ─────────────────────────────────────────────────────────────────

/** A clock the fakes advance by hand, so no test waits on real time. */
function fakeClock(startMs = 1_700_000_000_000) {
  let current = startMs;
  return {
    now: () => current,
    advance: (ms: number) => {
      current += ms;
    },
  };
}

/** What one fake leg does: answer with a string, or throw, after `elapseMs`. */
interface LegSpec {
  readonly outcome: string | Error;
  readonly elapseMs?: number;
}

/** Records the budget of every attempt that got a live timer. */
function recordingTimer() {
  const budgets: number[] = [];
  return {
    budgets,
    timeoutSignal: (ms: number) => {
      budgets.push(ms);
      return new AbortController().signal;
    },
  };
}

type LoggedEvent = { event: string; fields: Record<string, unknown> };

/** Captures what the chain reports, so no test has to read stdout. */
function capturingLog() {
  const lines: LoggedEvent[] = [];
  const log = (event: string, fields: Record<string, unknown> = {}) => {
    lines.push({ event, fields });
  };
  return { log: log as LegChainOptions<string, string>["log"], lines };
}

/**
 * A chain over as many fake legs as `specs` has entries, each named by its
 * position, with the clock, timer and log all injected.
 */
function setup(
  specs: readonly LegSpec[],
  overrides: Partial<LegChainOptions<string, string>> = {},
) {
  const clock = fakeClock();
  const timer = recordingTimer();
  const { log, lines } = capturingLog();
  const calls: number[] = specs.map(() => 0);

  const legs: ChainLeg<string, string>[] = specs.map((spec, index) => ({
    name: NAMES[index],
    run: (_input: string, _signal: AbortSignal) => {
      calls[index]++;
      clock.advance(spec.elapseMs ?? 0);
      return spec.outcome instanceof Error
        ? Promise.reject(spec.outcome)
        : Promise.resolve(spec.outcome);
    },
  }));

  const chain = createLegChain<string, string>({
    legs,
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    event: EVENT,
    apiErrorFor: analysisApiErrorFor,
    now: clock.now,
    timeoutSignal: timer.timeoutSignal,
    log,
    ...overrides,
  });

  return { chain, clock, calls, budgets: timer.budgets, lines };
}

async function failureCode(run: () => Promise<unknown>): Promise<string> {
  const thrown = await assertRejects(run, ApiError);
  return (thrown as ApiError).code;
}

// ── the chain's own shape ─────────────────────────────────────────────────

Deno.test("a chain with no legs is refused when it is built, not when it is called", () => {
  // The legs come from config at deploy time, so an empty chain is a
  // programmer error that must surface before a user pays a slot for it.
  assertThrows(
    () =>
      createLegChain<string, string>({
        legs: [],
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        event: EVENT,
        apiErrorFor: analysisApiErrorFor,
      }),
    RangeError,
  );
});

// ── three legs, the happy paths ───────────────────────────────────────────

Deno.test("the first leg answering stops the chain there", async () => {
  const { chain, calls, lines } = setup([
    { outcome: "first" },
    { outcome: "second" },
    { outcome: "third" },
  ]);

  assertEquals(await chain(INPUT), "first");
  assertEquals(calls, [1, 0, 0]);
  assertEquals(lines[0].fields.provider, "gemini_read_1");
  assertEquals(lines[0].fields.failed_over, false);
});

Deno.test("the second leg succeeding stops the chain, and the third never runs", async () => {
  const { chain, calls, lines } = setup([
    { outcome: RATE_LIMITED, elapseMs: 200 },
    { outcome: "second" },
    { outcome: "third" },
  ]);

  assertEquals(await chain(INPUT), "second");
  assertEquals(calls, [1, 1, 0]);
  assertEquals(lines.length, 1, "one line per stage, however many legs ran");
  assertEquals(lines[0].fields.provider, "gemini_read_2");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(lines[0].fields.primary_failure, "rate_limited");
  assertEquals(lines[0].fields.error_code, undefined, "the stage succeeded");
});

Deno.test("the third leg answers after two eligible failures", async () => {
  // The case two legs could not express at all, and the reason T07 has three:
  // leg 3 answering means both buckets in front of it are spent.
  const { chain, calls, lines } = setup([
    { outcome: RATE_LIMITED, elapseMs: 200 },
    { outcome: RATE_LIMITED, elapseMs: 200 },
    { outcome: "third" },
  ]);

  assertEquals(await chain(INPUT), "third");
  assertEquals(calls, [1, 1, 1]);
  assertEquals(lines[0].fields.provider, "gemini_read_3");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(
    lines[0].fields.primary_failure,
    "rate_limited",
    "the FIRST leg's kind, not the middle one's",
  );
});

// ── every leg fails (A10, generalised) ────────────────────────────────────

Deno.test("every leg failing answers the LAST leg's failure, not the first's", async () => {
  // Reporting the first 429 when the third leg 5xx'd would name a leg that is
  // not the one that ultimately failed, and hide a genuine third outage.
  const { chain, calls, lines } = setup([
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: SERVER_ERROR, elapseMs: 100 },
  ]);

  assertEquals(await failureCode(() => chain(INPUT)), "ANALYSIS_FAILED");
  assertEquals(calls, [1, 1, 1]);
  assertEquals(lines.length, 1);
  assertEquals(lines[0].fields.provider, "gemini_read_3");
  assertEquals(lines[0].fields.primary_failure, "rate_limited");
  assertEquals(lines[0].fields.failure, "upstream_unavailable");
  assertEquals(lines[0].fields.error_code, "ANALYSIS_FAILED");
  assertEquals(
    lines[0].fields.failover_skipped,
    undefined,
    "a chain that failed over and then ran out of legs has already said so",
  );
});

Deno.test("there is no fourth attempt", async () => {
  // The chain is its legs, not a retry loop.
  const { chain, calls } = setup([
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: RATE_LIMITED, elapseMs: 100 },
  ]);

  assertEquals(await failureCode(() => chain(INPUT)), "AI_RATE_LIMITED");
  assertEquals(calls, [1, 1, 1]);
});

// ── an ineligible failure stops a chain mid-way (A6, A7, A9) ──────────────

Deno.test("a bad key on the SECOND leg stops the chain before the third", async () => {
  // Two legs could only ever test this on the primary. A deploy fault behind
  // the first leg is just as much a deploy fault, and must not be papered over
  // by a leg that still has quota.
  const { chain, calls, lines } = setup([
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: BAD_KEY, elapseMs: 100 },
    { outcome: "third" },
  ]);

  assertEquals(await failureCode(() => chain(INPUT)), "INTERNAL_ERROR");
  assertEquals(calls, [1, 1, 0], "a config fault must not be retried");
  assertEquals(lines[0].fields.provider, "gemini_read_2");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(lines[0].fields.failure, "auth");
  assertEquals(lines[0].fields.failover_skipped, "not_fallback_eligible");
});

Deno.test("a bug in our own code on the second leg is never retried (A9)", async () => {
  const bug = new TypeError("cannot read properties of undefined");
  const { chain, calls, lines } = setup([
    { outcome: SERVER_ERROR, elapseMs: 100 },
    { outcome: bug, elapseMs: 100 },
    { outcome: "third" },
  ]);

  const thrown = await assertRejects(() => chain(INPUT), ApiError);

  assertEquals((thrown as ApiError).code, "INTERNAL_ERROR");
  // Discarded, exactly as the endpoint boundary would: an exception's message
  // can quote the payload that caused it.
  assert(!(thrown as ApiError).message.includes("undefined"));
  assertEquals(calls, [1, 1, 0]);
  assertEquals(lines[0].fields.failure, undefined, "not a ProviderFailure");
  assertEquals(lines[0].fields.failover_skipped, "not_fallback_eligible");
});

// ── no time for the last leg (§2) ─────────────────────────────────────────

Deno.test("no time for leg 3 ends the chain on leg 2's failure", async () => {
  // 25 s total: leg 1 burns 18 s to its cap, leg 2 burns 3 s, leaving 4 s —
  // below the 5 s floor, so the third call is not worth starting.
  const { chain, calls, lines, budgets } = setup([
    { outcome: PROVIDER_TIMEOUT, elapseMs: DEFAULT_ATTEMPT_CAP_MS },
    { outcome: SERVER_ERROR, elapseMs: 3_000 },
    { outcome: "third" },
  ]);

  assertEquals(await failureCode(() => chain(INPUT)), "ANALYSIS_FAILED");
  assertEquals(calls, [1, 1, 0]);
  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS, 7_000], "leg 2 got what leg 1 spared");
  assertEquals(lines[0].fields.provider, "gemini_read_2");
  assertEquals(lines[0].fields.failover_skipped, "insufficient_budget");
});

Deno.test("exactly the floor left still reaches leg 3", async () => {
  // Pins the boundary rather than a value either side of it.
  const { chain, calls, budgets } = setup([
    { outcome: RATE_LIMITED, elapseMs: 10_000 },
    { outcome: RATE_LIMITED, elapseMs: TOTAL_SECONDS * 1000 - 10_000 - DEFAULT_MIN_FALLBACK_MS },
    { outcome: "third" },
  ]);

  assertEquals(await chain(INPUT), "third");
  assertEquals(calls, [1, 1, 1]);
  assertEquals(budgets[2], DEFAULT_MIN_FALLBACK_MS);
});

Deno.test("one millisecond below the floor does not reach leg 3", async () => {
  const { chain, calls } = setup([
    { outcome: RATE_LIMITED, elapseMs: 10_000 },
    {
      outcome: RATE_LIMITED,
      elapseMs: TOTAL_SECONDS * 1000 - 10_000 - DEFAULT_MIN_FALLBACK_MS + 1,
    },
    { outcome: "third" },
  ]);

  assertEquals(await failureCode(() => chain(INPUT)), "AI_RATE_LIMITED");
  assertEquals(calls, [1, 1, 0]);
});

Deno.test("three legs cannot together outlive the deadline", async () => {
  // Whatever the arity, the budget is the stage's, not per leg: the handler's
  // slot-TTL arithmetic depends on it.
  const { chain, budgets } = setup([
    { outcome: RATE_LIMITED, elapseMs: 6_000 },
    { outcome: RATE_LIMITED, elapseMs: 6_000 },
    { outcome: "third", elapseMs: 6_000 },
  ]);

  await chain(INPUT);

  // 25 s − 6 s = 19 s left for leg 2, still bounded by the 18 s cap; leg 3
  // then gets the 13 s that genuinely remain, under the cap and so uncapped.
  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS, DEFAULT_ATTEMPT_CAP_MS, 13_000]);
  assert(budgets.slice(1).every((b) => b < TOTAL_SECONDS * 1000));
});

// ── the stage's own event and mapping ─────────────────────────────────────

Deno.test("the chain logs under the event its stage was given", async () => {
  // Two chains run in one `explain-document` request; a shared event name
  // would make the log explorer unable to tell reading from explaining.
  const { chain, lines } = setup([{ outcome: "first" }]);

  await chain(INPUT);

  assertEquals(lines[0].event, EVENT);
});

Deno.test("the §31 mapping is the stage's, not a default", async () => {
  // `ocr-document` maps an unusable answer to OCR_UNAVAILABLE where the
  // analysis maps it to ANALYSIS_FAILED. The chain must never pick for them.
  const { chain } = setup([{ outcome: SERVER_ERROR }], {
    apiErrorFor: () => ApiError.ocrUnavailable(),
  });

  assertEquals(await failureCode(() => chain(INPUT)), "OCR_UNAVAILABLE");
});

// ── privacy (§7, §51) ─────────────────────────────────────────────────────

Deno.test("the log never carries the input or the answer, at any arity", async () => {
  const { chain, lines } = setup([
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: RATE_LIMITED, elapseMs: 100 },
    { outcome: RATE_LIMITED, elapseMs: 100 },
  ]);

  await assertRejects(() => chain(INPUT));

  const serialised = JSON.stringify(lines);
  assert(!serialised.includes("850"), "an amount reached the log");
  assert(!serialised.includes("فاتورة"), "document text reached the log");
  assertEquals(
    Object.keys(lines[0].fields).sort(),
    [
      "error_code",
      "failed_over",
      "failover_skipped",
      "failure",
      "primary_failure",
      "provider",
      "request_id",
    ],
    "an unexpected field appeared — check it carries no content",
  );
});
