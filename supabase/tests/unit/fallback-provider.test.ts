/**
 * F18-T05, rewritten in F20-T10 · Tests for the fallback chain.
 *
 * The legs throw `ProviderFailure`, and the chain alone decides fallback
 * eligibility (failure matrix §1, rows A1–A10), times both attempts from one
 * request `Deadline` (timeout contract §2), and maps whatever ends the request
 * onto a §31 `ApiError`.
 *
 * Entirely offline: both legs are fakes, the clock is injected, and so is the
 * timer behind each attempt's signal, which is how the tests read every budget
 * the chain hands out without waiting on real time.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  createFallbackAnalysisProvider,
  DEFAULT_ATTEMPT_CAP_MS,
  DEFAULT_MIN_FALLBACK_MS,
  type FallbackAnalysisProviderOptions,
} from "../../functions/_shared/ai/fallback-provider.ts";
import type { AnalysisLeg } from "../../functions/_shared/ai/analysis-provider.ts";
import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";
import type { AnalysisPromptInput } from "../../functions/_shared/prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../../functions/_shared/schemas/analysis-output.schema.ts";

const INPUT: AnalysisPromptInput = {
  ocrText: "فاتورة كهرباء بمبلغ 850 جنيه",
  detectedLanguages: ["ar"],
  candidates: {
    dates: [],
    times: [],
    amounts: [],
    phones: [],
    references: [],
  },
};

function analysis(label: string): ModelAnalysis {
  return {
    status: "success",
    document_type: { type: "invoice", title: label, confidence: "high" },
    summary: { short: label, detailed: label },
    key_information: [],
    dates: [],
    amounts: [],
    actions_required: [],
    required_documents: [],
    instructions: [],
    warnings: [],
    missing_fields: [],
  };
}

const TOTAL_SECONDS = 25;
const REQUEST_ID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";

/** Fallback-eligible failures (matrix rows A1–A5). */
const RATE_LIMITED = new ProviderFailure("rate_limited");
const SERVER_ERROR = new ProviderFailure("upstream_unavailable");
const NETWORK_ERROR = new ProviderFailure("network");
const PROVIDER_TIMEOUT = new ProviderFailure("timeout");
const UNUSABLE_OUTPUT = new ProviderFailure("invalid_output");

/** Our own faults, never retried against a second provider (A6, A7). */
const BAD_KEY = new ProviderFailure("auth");
const BAD_REQUEST = new ProviderFailure("bad_request");

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

/**
 * A recording leg. It advances the clock by `elapseMs` (the time the call
 * "took"), then answers or throws. `calls` counts invocations, and `signals`
 * keeps each call's signal, so a test can tell an already-expired attempt.
 */
function leg(clock: ReturnType<typeof fakeClock>, outcome: ModelAnalysis | Error, elapseMs = 0) {
  const signals: AbortSignal[] = [];
  const fn: AnalysisLeg = (_input, signal) => {
    signals.push(signal);
    clock.advance(elapseMs);
    return outcome instanceof Error ? Promise.reject(outcome) : Promise.resolve(outcome);
  };
  return {
    fn,
    signals,
    get calls() {
      return signals.length;
    },
  };
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
  return { log: log as FallbackAnalysisProviderOptions["log"], lines };
}

/**
 * A Mistral → Groq chain over the given legs, with the clock, timer and log
 * all injected. `fallback: null` builds a single-leg chain.
 */
function setup(
  primaryOutcome: ModelAnalysis | Error,
  primaryElapseMs: number,
  fallbackOutcome: ModelAnalysis | Error | null,
  fallbackElapseMs = 0,
  overrides: Partial<FallbackAnalysisProviderOptions> = {},
) {
  const clock = fakeClock();
  const timer = recordingTimer();
  const { log, lines } = capturingLog();
  const primary = leg(clock, primaryOutcome, primaryElapseMs);
  const fallback = fallbackOutcome === null ? null : leg(clock, fallbackOutcome, fallbackElapseMs);

  const provider = createFallbackAnalysisProvider({
    primary: primary.fn,
    primaryName: "mistral",
    fallback: fallback?.fn ?? null,
    fallbackName: fallback === null ? null : "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: clock.now,
    timeoutSignal: timer.timeoutSignal,
    log,
    ...overrides,
  });

  return { provider, clock, primary, fallback, budgets: timer.budgets, lines };
}

async function failureCode(run: () => Promise<unknown>): Promise<string> {
  const thrown = await assertRejects(run, ApiError);
  return (thrown as ApiError).code;
}

// ── the constants the benchmark set (F20-T09) ─────────────────────────────

Deno.test("the defaults are the T09 values: an 18 s cap and a 5 s fallback floor", () => {
  assertEquals(DEFAULT_ATTEMPT_CAP_MS, 18_000);
  assertEquals(DEFAULT_MIN_FALLBACK_MS, 5_000);
});

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("a successful primary is returned as-is, and the fallback never runs", async () => {
  const { provider, fallback } = setup(analysis("primary"), 0, analysis("fallback"));

  const result = await provider(INPUT);

  assertEquals(result.document_type.title, "primary");
  assertEquals(fallback!.calls, 0);
});

Deno.test("the primary's budget is the attempt cap, not the whole deadline", async () => {
  // The cap is what keeps a hung primary from starving the fallback.
  const { provider, budgets } = setup(analysis("primary"), 0, analysis("fallback"));

  await provider(INPUT);

  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS]);
});

Deno.test("a cap longer than the deadline is bounded by the deadline", async () => {
  const { provider, budgets } = setup(analysis("primary"), 0, null, 0, { totalSeconds: 10 });

  await provider(INPUT);

  assertEquals(budgets, [10_000]);
});

Deno.test("the deadline starts when the analysis is called, not when the chain is built", async () => {
  // The chain is built before the slot is reserved; that wait must not come
  // out of the providers' budget.
  const { provider, clock, budgets } = setup(analysis("primary"), 0, null);

  clock.advance(60_000);
  await provider(INPUT);

  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS]);
});

Deno.test("a custom cap and floor are honoured", async () => {
  // 25 s total, 10 s cap: the primary hangs to its cap, 15 s remain, and a
  // 16 s floor refuses the fallback.
  const { provider, fallback, budgets } = setup(PROVIDER_TIMEOUT, 10_000, analysis("fallback"), 0, {
    attemptCapMs: 10_000,
    minFallbackMs: 16_000,
  });

  assertEquals(await failureCode(() => provider(INPUT)), "TIMEOUT");
  assertEquals(budgets, [10_000]);
  assertEquals(fallback!.calls, 0);
});

// ── what fails over (A1–A5) ───────────────────────────────────────────────

for (
  const [name, failure] of [
    ["a 429 fails over (A1)", RATE_LIMITED],
    ["a 5xx fails over (A2)", SERVER_ERROR],
    ["a timeout with budget left fails over (A3)", PROVIDER_TIMEOUT],
    ["a network error fails over (A4)", NETWORK_ERROR],
    ["an unusable answer fails over (A5)", UNUSABLE_OUTPUT],
  ] as const
) {
  Deno.test(name, async () => {
    const { provider, fallback } = setup(failure, 200, analysis("fallback"));

    const result = await provider(INPUT);

    assertEquals(result.document_type.title, "fallback");
    assertEquals(fallback!.calls, 1);
  });
}

// ── how much time the fallback gets (§2) ──────────────────────────────────

Deno.test("a fast failure leaves the fallback a full capped attempt", async () => {
  // A 429 in 200 ms leaves 24.8 s; the fallback still gets only the cap.
  const { provider, budgets } = setup(RATE_LIMITED, 200, analysis("fallback"));

  await provider(INPUT);

  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS, DEFAULT_ATTEMPT_CAP_MS]);
});

Deno.test("a slow failure leaves the fallback only what genuinely remains", async () => {
  const { provider, budgets } = setup(SERVER_ERROR, 14_000, analysis("fallback"));

  await provider(INPUT);

  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS, 11_000], "25 s − 14 s elapsed");
});

Deno.test("a primary that hangs to its cap still leaves the fallback time", async () => {
  // The case the cap exists for: 25 s − 18 s = 7 s ≥ the 5 s floor.
  const { provider, budgets, lines } = setup(
    PROVIDER_TIMEOUT,
    DEFAULT_ATTEMPT_CAP_MS,
    analysis("fallback"),
  );

  const result = await provider(INPUT);

  assertEquals(result.document_type.title, "fallback");
  assertEquals(budgets, [DEFAULT_ATTEMPT_CAP_MS, 7_000]);
  assertEquals(lines[0].fields.primary_failure, "timeout");
});

Deno.test("exactly the floor left still fails over", async () => {
  // Pins the boundary rather than a value either side of it.
  const elapse = TOTAL_SECONDS * 1000 - DEFAULT_MIN_FALLBACK_MS;
  const { provider, budgets } = setup(SERVER_ERROR, elapse, analysis("fallback"));

  const result = await provider(INPUT);

  assertEquals(result.document_type.title, "fallback");
  assertEquals(budgets[1], DEFAULT_MIN_FALLBACK_MS);
});

Deno.test("one millisecond below the floor does not fail over", async () => {
  const elapse = TOTAL_SECONDS * 1000 - DEFAULT_MIN_FALLBACK_MS + 1;
  const { provider, fallback } = setup(SERVER_ERROR, elapse, analysis("fallback"));

  assertEquals(await failureCode(() => provider(INPUT)), "ANALYSIS_FAILED");
  assertEquals(fallback!.calls, 0);
});

Deno.test("a timeout that left too little time answers TIMEOUT (A3)", async () => {
  // One failure is better than two and a doubled wait.
  const { provider, fallback, lines } = setup(PROVIDER_TIMEOUT, 22_000, analysis("fallback"));

  assertEquals(await failureCode(() => provider(INPUT)), "TIMEOUT");
  assertEquals(fallback!.calls, 0);
  assertEquals(lines[0].fields.failover_skipped, "insufficient_budget");
});

Deno.test("an exhausted deadline answers TIMEOUT without a second call", async () => {
  const { provider, fallback } = setup(PROVIDER_TIMEOUT, 30_000, analysis("fallback"));

  assertEquals(await failureCode(() => provider(INPUT)), "TIMEOUT");
  assertEquals(fallback!.calls, 0);
});

// ── what does not fail over (A6, A7, A9) ──────────────────────────────────

for (
  const [name, failure] of [
    ["a bad key does NOT fail over (A6)", BAD_KEY],
    ["a bad request or model name does NOT fail over (A7)", BAD_REQUEST],
  ] as const
) {
  Deno.test(name, async () => {
    // Our own deploy fault. Asking a second provider would serve the request
    // and hide the misconfiguration until the fallback's quota ran out too.
    const { provider, fallback, lines } = setup(failure, 300, analysis("fallback"));

    assertEquals(await failureCode(() => provider(INPUT)), "INTERNAL_ERROR");
    assertEquals(fallback!.calls, 0, "a config fault must not be retried");
    assertEquals(lines[0].fields.failover_skipped, "not_fallback_eligible");
    assertEquals(lines[0].fields.failure, failure.kind);
  });
}

Deno.test("a bug in our own code is never retried and surfaces as INTERNAL_ERROR (A9)", async () => {
  // Retrying it against a second provider would run the same broken path twice.
  const bug = new TypeError("cannot read properties of undefined");
  const { provider, fallback, lines } = setup(bug, 100, analysis("fallback"));

  const thrown = await assertRejects(() => provider(INPUT), ApiError);

  assertEquals((thrown as ApiError).code, "INTERNAL_ERROR");
  // Discarded, exactly as the endpoint boundary would: an exception's message
  // can quote the payload that caused it.
  assert(!(thrown as ApiError).message.includes("undefined"));
  assertEquals(fallback!.calls, 0);
  assertEquals(lines[0].fields.primary_failure, undefined);
  assertEquals(lines[0].fields.failover_skipped, "not_fallback_eligible");
});

Deno.test("an unconfigured fallback maps the primary's failure onto the wire", async () => {
  const { provider, lines } = setup(RATE_LIMITED, 200, null);

  const thrown = await assertRejects(() => provider(INPUT), ApiError);

  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
  assertEquals((thrown as ApiError).status, 429);
  assertEquals(lines[0].fields.failover_skipped, "no_fallback_configured");
});

// ── when both legs fail (A10) ─────────────────────────────────────────────

Deno.test("the fallback's own failure is the answer, not the primary's", async () => {
  // Reporting the primary's 429 when the fallback 5xx'd would name a provider
  // that is not the one that ultimately failed, and hide a real second outage.
  const { provider, fallback } = setup(RATE_LIMITED, 200, SERVER_ERROR, 500);

  assertEquals(await failureCode(() => provider(INPUT)), "ANALYSIS_FAILED");
  assertEquals(fallback!.calls, 1);
});

Deno.test("a fallback that times out answers TIMEOUT", async () => {
  const { provider } = setup(RATE_LIMITED, 200, PROVIDER_TIMEOUT, 18_000);

  assertEquals(await failureCode(() => provider(INPUT)), "TIMEOUT");
});

Deno.test("a fallback with a bug answers INTERNAL_ERROR", async () => {
  const { provider } = setup(RATE_LIMITED, 200, new TypeError("oops"));

  assertEquals(await failureCode(() => provider(INPUT)), "INTERNAL_ERROR");
});

Deno.test("there is no third attempt", async () => {
  // The chain is two legs, not a retry loop. A fallback that also 429s ends it.
  const { provider, primary, fallback } = setup(RATE_LIMITED, 100, RATE_LIMITED, 100);

  assertEquals(await failureCode(() => provider(INPUT)), "AI_RATE_LIMITED");
  assertEquals(primary.calls, 1);
  assertEquals(fallback!.calls, 1);
});

// ── the analyze.provider line (F18-T07) ──────────────────────────────────
// On free tiers this is the only instrument that says how often 429s are
// pushing traffic to the fallback — the signal that the day's capacity is gone.
// Exactly one line per analysis, on every path, success or failure.

Deno.test("a served primary logs itself, with no failover", async () => {
  const { provider, lines } = setup(analysis("primary"), 0, analysis("fallback"));

  await provider(INPUT);

  assertEquals(lines.length, 1);
  assertEquals(lines[0].event, "analyze.provider");
  assertEquals(lines[0].fields.request_id, REQUEST_ID);
  assertEquals(lines[0].fields.provider, "mistral");
  assertEquals(lines[0].fields.failed_over, false);
  assertEquals(lines[0].fields.primary_failure, undefined);
  assertEquals(lines[0].fields.error_code, undefined);
});

Deno.test("a failover names the provider that ANSWERED, and the kind that pushed it there", async () => {
  const { provider, lines } = setup(RATE_LIMITED, 200, analysis("fallback"));

  await provider(INPUT);

  assertEquals(lines.length, 1);
  assertEquals(lines[0].fields.provider, "groq");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(lines[0].fields.primary_failure, "rate_limited");
  assertEquals(lines[0].fields.error_code, undefined, "the request succeeded");
});

Deno.test("both legs failing reports both kinds on one line", async () => {
  const { provider, lines } = setup(RATE_LIMITED, 100, SERVER_ERROR, 100);

  await assertRejects(() => provider(INPUT));

  assertEquals(lines.length, 1, "one line per analysis, even on a double failure");
  assertEquals(lines[0].fields.provider, "groq");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(lines[0].fields.primary_failure, "rate_limited");
  assertEquals(lines[0].fields.failure, "upstream_unavailable");
  assertEquals(lines[0].fields.error_code, "ANALYSIS_FAILED");
});

Deno.test("the log never carries the document (§7, §51)", async () => {
  // The chain handles the OCR text on every call and must never record a word of
  // it. Provider names, failure kinds and §31 codes are labels, not content.
  const { provider, lines } = setup(RATE_LIMITED, 0, null);

  await assertRejects(() => provider(INPUT));

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
