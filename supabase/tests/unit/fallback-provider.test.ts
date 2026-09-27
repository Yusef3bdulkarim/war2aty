/**
 * F18-T05 · Tests for the fallback chain.
 *
 * The heart of the feature, and entirely offline: both legs are fakes, and the
 * clock is injected. Nothing here touches a network or a real provider, so the
 * failover rule is pinned by behaviour rather than by observation in production.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  createFallbackAnalysisProvider,
  MIN_FALLBACK_SECONDS,
  PRIMARY_SHARE,
  resolveProviderOrder,
} from "../../functions/_shared/ai/fallback-provider.ts";
import type { AiAnalysisProvider } from "../../functions/_shared/ai/analysis-provider.ts";
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

/**
 * A recording provider factory.
 *
 * `budgets` captures the seconds each construction was given, which is also how
 * the tests prove a leg was never built at all.
 */
function leg(outcome: ModelAnalysis | Error, elapseMs = 0) {
  const budgets: number[] = [];
  let clock: { advance: (ms: number) => void } | undefined;

  const factory = (seconds: number): AiAnalysisProvider => {
    budgets.push(seconds);
    return () => {
      clock?.advance(elapseMs);
      if (outcome instanceof Error) return Promise.reject(outcome);
      return Promise.resolve(outcome);
    };
  };

  return {
    factory,
    budgets,
    bindClock(c: { advance: (ms: number) => void }) {
      clock = c;
      return this;
    },
  };
}

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

/** The transport's errors — the only ones that may trigger a failover. */
const RATE_LIMITED = ApiError.aiRateLimited().asProviderFault();
const SERVER_ERROR = ApiError.analysisFailed().asProviderFault();
const NETWORK_ERROR = ApiError.analysisFailed().asProviderFault();
const PROVIDER_TIMEOUT = ApiError.timeout().asProviderFault();

/** The parser's error — a considered answer about a bad document. */
const UNUSABLE_JSON = ApiError.analysisFailed();

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("a successful primary is returned as-is", async () => {
  const primary = leg(analysis("primary"));
  const fallback = leg(analysis("fallback"));

  const provider = createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: fallback.factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: fakeClock().now,
  });

  const result = await provider(INPUT);

  assertEquals(result.document_type.title, "primary");
});

Deno.test("a successful primary never constructs the fallback", async () => {
  // Construction reads env and builds an HTTP client. Doing it for a request
  // that will never use it is waste on every single analysis — which is why the
  // legs are factories rather than instances.
  const primary = leg(analysis("primary"));
  const fallback = leg(analysis("fallback"));

  await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: fallback.factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: fakeClock().now,
  })(INPUT);

  assertEquals(fallback.budgets, [], "the fallback was built and should not be");
});

Deno.test("the primary gets its share of the budget", async () => {
  const primary = leg(analysis("primary"));

  await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: null,
    fallbackName: null,
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: fakeClock().now,
  })(INPUT);

  assertEquals(primary.budgets, [Math.floor(TOTAL_SECONDS * PRIMARY_SHARE)]);
  assertEquals(primary.budgets, [15], "25s * 0.6, floored");
});

// ── what fails over ───────────────────────────────────────────────────────

for (
  const [name, error] of [
    ["a 429 fails over", RATE_LIMITED],
    ["a 5xx fails over", SERVER_ERROR],
    ["a network error fails over", NETWORK_ERROR],
  ] as const
) {
  Deno.test(name, async () => {
    const clock = fakeClock();
    const primary = leg(error, 200).bindClock(clock);
    const fallback = leg(analysis("fallback"));

    const result = await createFallbackAnalysisProvider({
      primary: primary.factory,
      primaryName: "gemini",
      fallback: fallback.factory,
      fallbackName: "groq",
      totalSeconds: TOTAL_SECONDS,
      requestId: REQUEST_ID,
      now: clock.now,
    })(INPUT);

    assertEquals(result.document_type.title, "fallback");
  });
}

Deno.test("a timeout with budget left fails over", async () => {
  // A primary that aborts early — a hung connection dropped at 5s, not one that
  // consumed its whole 15s share.
  const clock = fakeClock();
  const primary = leg(PROVIDER_TIMEOUT, 5_000).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  const result = await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: fallback.factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: clock.now,
  })(INPUT);

  assertEquals(result.document_type.title, "fallback");
});

Deno.test("the fallback receives the genuinely remaining seconds", async () => {
  // Not a fraction, and not the primary's share: what is actually left. A
  // primary that 429s in 200ms leaves the fallback nearly the whole envelope,
  // which is the common case on a free tier.
  const clock = fakeClock();
  const primary = leg(RATE_LIMITED, 200).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: fallback.factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: clock.now,
  })(INPUT);

  assertEquals(fallback.budgets, [24], "25s - 0.2s elapsed, floored");
});

Deno.test("a slow primary leaves the fallback correspondingly less", async () => {
  const clock = fakeClock();
  const primary = leg(SERVER_ERROR, 14_000).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: fallback.factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: clock.now,
  })(INPUT);

  assertEquals(fallback.budgets, [11], "25s - 14s elapsed");
});

// ── what does not fail over ───────────────────────────────────────────────

Deno.test("a timeout that consumed the budget does NOT fail over", async () => {
  // The primary burned its full 15s share, leaving 10s — but a second call
  // needs MIN_FALLBACK_SECONDS to stand a chance, and here it would be racing
  // the same wall. One failure is better than two and a doubled wait.
  const clock = fakeClock();
  const primary = leg(PROVIDER_TIMEOUT, 18_000).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  const thrown = await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: fallback.factory,
        fallbackName: "groq",
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "TIMEOUT");
  assertEquals(fallback.budgets, [], "no second call should have been built");
});

Deno.test("the budget floor is exactly MIN_FALLBACK_SECONDS, not one less", async () => {
  // Pins the boundary rather than a value either side of it. Elapsing exactly
  // enough to leave MIN_FALLBACK_SECONDS must still fail over.
  const clock = fakeClock();
  const elapseMs = (TOTAL_SECONDS - MIN_FALLBACK_SECONDS) * 1000;
  const primary = leg(SERVER_ERROR, elapseMs).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  const result = await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: fallback.factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: clock.now,
  })(INPUT);

  assertEquals(result.document_type.title, "fallback");
  assertEquals(fallback.budgets, [MIN_FALLBACK_SECONDS]);
});

Deno.test("one second below the floor does not fail over", async () => {
  const clock = fakeClock();
  const elapseMs = (TOTAL_SECONDS - MIN_FALLBACK_SECONDS + 1) * 1000;
  const primary = leg(SERVER_ERROR, elapseMs).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: fallback.factory,
        fallbackName: "groq",
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    ApiError,
  );

  assertEquals(fallback.budgets, []);
});

Deno.test("malformed-but-200 JSON does NOT fail over", async () => {
  // The model answered; the answer was unusable. That is a judgement about the
  // document, not a provider failure, and the other model will usually agree.
  // This is the case that keeps the chain from doubling latency for nothing.
  const clock = fakeClock();
  const primary = leg(UNUSABLE_JSON, 300).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  const thrown = await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: fallback.factory,
        fallbackName: "groq",
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
  assertEquals((thrown as ApiError).providerFault, false);
  assertEquals(fallback.budgets, [], "an unusable answer must not be retried");
});

Deno.test("an unconfigured fallback rethrows the primary's error unchanged", async () => {
  // The default state, and bit-for-bit the behaviour before this feature.
  const clock = fakeClock();
  const primary = leg(RATE_LIMITED, 200).bindClock(clock);

  const thrown = await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: null,
        fallbackName: null,
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    ApiError,
  );

  assertEquals(thrown, RATE_LIMITED, "the very same error instance");
  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
});

Deno.test("a non-ApiError surfaces as itself and is never retried", async () => {
  // A TypeError here is a bug in our own code. Retrying it against a second
  // provider would run the same broken path twice and bury the stack trace.
  const clock = fakeClock();
  const bug = new TypeError("cannot read properties of undefined");
  const primary = leg(bug, 100).bindClock(clock);
  const fallback = leg(analysis("fallback"));

  const thrown = await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: fallback.factory,
        fallbackName: "groq",
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    TypeError,
  );

  assertEquals(thrown.message, "cannot read properties of undefined");
  assertEquals(fallback.budgets, []);
});

// ── when the fallback itself fails ────────────────────────────────────────

Deno.test("the fallback's own failure surfaces, not the primary's", async () => {
  // Reporting the primary's 429 when the fallback 5xx'd would name a provider
  // that is not the one that ultimately failed, and hide a real second outage.
  const clock = fakeClock();
  const primary = leg(RATE_LIMITED, 200).bindClock(clock);
  const fallback = leg(ApiError.analysisFailed().asProviderFault(), 500)
    .bindClock(clock);

  const thrown = await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: fallback.factory,
        fallbackName: "groq",
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
  assertEquals(fallback.budgets.length, 1, "the fallback did run");
});

Deno.test("there is no third attempt", async () => {
  // The chain is two legs, not a retry loop. A fallback that also 429s ends it.
  const clock = fakeClock();
  const primary = leg(RATE_LIMITED, 100).bindClock(clock);
  const fallback = leg(RATE_LIMITED, 100).bindClock(clock);

  await assertRejects(
    () =>
      createFallbackAnalysisProvider({
        primary: primary.factory,
        primaryName: "gemini",
        fallback: fallback.factory,
        fallbackName: "groq",
        totalSeconds: TOTAL_SECONDS,
        requestId: REQUEST_ID,
        now: clock.now,
      })(INPUT),
    ApiError,
  );

  assertEquals(primary.budgets.length, 1);
  assertEquals(fallback.budgets.length, 1);
});

// ── the flag the whole rule rests on ──────────────────────────────────────

Deno.test("asProviderFault marks a copy and leaves the original alone", () => {
  const original = ApiError.analysisFailed();
  const marked = original.asProviderFault();

  assertEquals(original.providerFault, false);
  assertEquals(marked.providerFault, true);
  assertEquals(marked.code, original.code);
  assertEquals(marked.message, original.message);
  assertEquals(marked.status, original.status);
});

Deno.test("providerFault defaults to false", () => {
  // So every error raised outside the transport is, correctly, not a failover
  // trigger — including any factory added later without a thought for F18.
  assertEquals(ApiError.analysisFailed().providerFault, false);
  assertEquals(ApiError.timeout().providerFault, false);
  assertEquals(ApiError.internalError().providerFault, false);
  assertEquals(ApiError.unauthorized().providerFault, false);
});

Deno.test("providerFault never reaches the wire", () => {
  // §31 defines the error envelope exactly; this flag is a server-side routing
  // hint and must not appear in it.
  const body = ApiError.aiRateLimited().asProviderFault().toBody();

  assertEquals(body, {
    error: {
      code: "AI_RATE_LIMITED",
      message: "AI provider rate limit reached.",
    },
  });
  assert(!JSON.stringify(body).includes("providerFault"));
});

Deno.test("details survive being marked a provider fault", () => {
  // `dailyLimitReached` is not a provider fault, but nothing should silently
  // drop `details` if a coded path ever marks an error that carries them.
  const marked = ApiError
    .dailyLimitReached("2026-09-27T00:00:00+03:00")
    .asProviderFault();

  assertEquals(marked.details, { reset_at: "2026-09-27T00:00:00+03:00" });
  assertEquals(marked.providerFault, true);
});

// ── the provider matrix (F18-T06) ─────────────────────────────────────────
// The rollout's safety rests on these four rows, so they are pinned as pure
// logic rather than left to the wiring file. Strings stand in for the legs: what
// is under test is WHICH leg goes where, not how one is built.

Deno.test("flag off with no Gemini key: Groq alone, exactly as before F18", () => {
  const order = resolveProviderOrder({
    geminiPrimary: false,
    groq: "groq-leg",
    gemini: null,
  });

  assertEquals(order.primary, "groq-leg");
  assertEquals(order.primaryName, "groq");
  assertEquals(order.fallback, null, "no second leg exists to fall back to");
  assertEquals(order.fallbackName, null);
});

Deno.test("flag off with a Gemini key: Groq first, Gemini takes the overflow", () => {
  // Useful on its own, before anyone flips the flag: Groq's ~66/day is spent
  // first and Gemini absorbs the 429s rather than the user seeing them.
  const order = resolveProviderOrder({
    geminiPrimary: false,
    groq: "groq-leg",
    gemini: "gemini-leg",
  });

  assertEquals(order.primaryName, "groq");
  assertEquals(order.fallbackName, "gemini");
});

Deno.test("flag on with a Gemini key: Gemini leads, Groq catches", () => {
  const order = resolveProviderOrder({
    geminiPrimary: true,
    groq: "groq-leg",
    gemini: "gemini-leg",
  });

  assertEquals(order.primary, "gemini-leg");
  assertEquals(order.primaryName, "gemini");
  assertEquals(order.fallback, "groq-leg");
  assertEquals(order.fallbackName, "groq");
});

Deno.test("flag on with NO Gemini key degrades to Groq alone, not to an outage", () => {
  // A config error, and the caller logs it — but the user still gets an answer.
  // Failing the request here would turn a flipped flag into a total outage.
  const order = resolveProviderOrder({
    geminiPrimary: true,
    groq: "groq-leg",
    gemini: null,
  });

  assertEquals(order.primaryName, "groq");
  assertEquals(order.fallbackName, null);
});

Deno.test("the flag never invents a second leg", () => {
  // Across both flag positions, an absent Gemini means exactly one leg. This is
  // what makes "merge with the flag absent" a no-op in production.
  for (const geminiPrimary of [true, false]) {
    const order = resolveProviderOrder({
      geminiPrimary,
      groq: "groq-leg",
      gemini: null,
    });

    assertEquals(order.primary, "groq-leg");
    assertEquals(order.fallback, null);
  }
});

Deno.test("a provider is never its own fallback", () => {
  // A chain that retried the same leg twice would burn double the quota to
  // learn the same thing.
  for (const geminiPrimary of [true, false]) {
    const order = resolveProviderOrder({
      geminiPrimary,
      groq: "groq-leg",
      gemini: "gemini-leg",
    });

    assert(order.primary !== order.fallback);
    assert(order.primaryName !== order.fallbackName);
  }
});

// ── the analyze.provider line (F18-T07) ──────────────────────────────────
// On free tiers this is the only instrument that says how often 429s are
// pushing traffic to the fallback — the signal that the day's capacity is gone.
// Exactly one line per analysis, on every path, success or failure.

type LoggedEvent = { event: string; fields: Record<string, unknown> };

/** Captures what the chain reports, so no test has to read stdout. */
function capturingLog() {
  const lines: LoggedEvent[] = [];
  const log = (event: string, fields: Record<string, unknown> = {}) => {
    lines.push({ event, fields });
  };
  return { log: log as never, lines };
}

/** The common single-provider-name shape, for the cases that do not need a clock. */
function chain(
  overrides: {
    primary: ReturnType<typeof leg>;
    fallback: ReturnType<typeof leg> | null;
    log: never;
  },
) {
  return createFallbackAnalysisProvider({
    primary: overrides.primary.factory,
    primaryName: "gemini",
    fallback: overrides.fallback === null ? null : overrides.fallback.factory,
    fallbackName: overrides.fallback === null ? null : "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    log: overrides.log,
  });
}

Deno.test("a served primary logs itself, with no failover", async () => {
  const { log, lines } = capturingLog();
  const primary = leg(analysis("primary"));

  await chain({ primary, fallback: leg(analysis("fallback")), log })(INPUT);

  assertEquals(lines.length, 1);
  assertEquals(lines[0].event, "analyze.provider");
  assertEquals(lines[0].fields.request_id, REQUEST_ID);
  assertEquals(lines[0].fields.provider, "gemini");
  assertEquals(lines[0].fields.failed_over, false);
  assertEquals(lines[0].fields.primary_error_code, undefined);
  assertEquals(lines[0].fields.error_code, undefined);
});

Deno.test("a failover names the provider that ANSWERED, and why it had to", async () => {
  // The two fields together are the whole instrument: `provider` is who served,
  // `primary_error_code` is what pushed the traffic there.
  const clock = fakeClock();
  const { log, lines } = capturingLog();
  const primary = leg(RATE_LIMITED, 200).bindClock(clock);

  const result = await createFallbackAnalysisProvider({
    primary: primary.factory,
    primaryName: "gemini",
    fallback: leg(analysis("fallback")).factory,
    fallbackName: "groq",
    totalSeconds: TOTAL_SECONDS,
    requestId: REQUEST_ID,
    now: clock.now,
    log,
  })(INPUT);

  assertEquals(result.document_type.title, "fallback");
  assertEquals(lines.length, 1);
  assertEquals(lines[0].fields.provider, "groq");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(lines[0].fields.primary_error_code, "AI_RATE_LIMITED");
  assertEquals(lines[0].fields.error_code, undefined, "the request succeeded");
});

Deno.test("a single-leg deployment records why it could not fail over", async () => {
  // The default state. Without this field a 429 with no fallback looks identical
  // to a 429 whose fallback was skipped for lack of budget.
  const { log, lines } = capturingLog();
  const primary = leg(RATE_LIMITED);

  await assertRejects(() => chain({ primary, fallback: null, log })(INPUT));

  assertEquals(lines.length, 1);
  assertEquals(lines[0].fields.provider, "gemini");
  assertEquals(lines[0].fields.failed_over, false);
  assertEquals(lines[0].fields.failover_skipped, "no_fallback_configured");
  assertEquals(lines[0].fields.error_code, "AI_RATE_LIMITED");
});

Deno.test("an unusable answer records that it was not a provider fault", async () => {
  const { log, lines } = capturingLog();
  const primary = leg(UNUSABLE_JSON);

  await assertRejects(() =>
    chain({ primary, fallback: leg(analysis("fallback")), log })(INPUT)
  );

  assertEquals(lines[0].fields.failover_skipped, "not_provider_fault");
  assertEquals(lines[0].fields.failed_over, false);
});

Deno.test("a budget-exhausted timeout records that too", async () => {
  // The field that answers "why did my fallback never fire?" — the single most
  // useful signal for tuning MIN_FALLBACK_SECONDS.
  const clock = fakeClock();
  const { log, lines } = capturingLog();
  const primary = leg(PROVIDER_TIMEOUT, 18_000).bindClock(clock);

  await assertRejects(() =>
    createFallbackAnalysisProvider({
      primary: primary.factory,
      primaryName: "gemini",
      fallback: leg(analysis("fallback")).factory,
      fallbackName: "groq",
      totalSeconds: TOTAL_SECONDS,
      requestId: REQUEST_ID,
      now: clock.now,
      log,
    })(INPUT)
  );

  assertEquals(lines[0].fields.failover_skipped, "insufficient_budget");
  assertEquals(lines[0].fields.primary_error_code, "TIMEOUT");
});

Deno.test("both legs failing reports both codes on one line", async () => {
  // A total outage must be readable as one: which provider was tried second,
  // what the first said, and what the second said.
  const clock = fakeClock();
  const { log, lines } = capturingLog();
  const primary = leg(RATE_LIMITED, 100).bindClock(clock);
  const fallback = leg(ApiError.analysisFailed().asProviderFault(), 100)
    .bindClock(clock);

  await assertRejects(() =>
    createFallbackAnalysisProvider({
      primary: primary.factory,
      primaryName: "gemini",
      fallback: fallback.factory,
      fallbackName: "groq",
      totalSeconds: TOTAL_SECONDS,
      requestId: REQUEST_ID,
      now: clock.now,
      log,
    })(INPUT)
  );

  assertEquals(lines.length, 1, "one line per analysis, even on a double failure");
  assertEquals(lines[0].fields.provider, "groq");
  assertEquals(lines[0].fields.failed_over, true);
  assertEquals(lines[0].fields.primary_error_code, "AI_RATE_LIMITED");
  assertEquals(lines[0].fields.error_code, "ANALYSIS_FAILED");
});

Deno.test("a bug in our own code is logged without a code it does not have", async () => {
  const { log, lines } = capturingLog();
  const primary = leg(new TypeError("cannot read properties of undefined"));

  await assertRejects(
    () => chain({ primary, fallback: leg(analysis("fallback")), log })(INPUT),
    TypeError,
  );

  assertEquals(lines[0].fields.primary_error_code, undefined);
  assertEquals(lines[0].fields.failover_skipped, "not_provider_fault");
});

Deno.test("the log never carries the document (§7, §51)", async () => {
  // The chain handles the OCR text on every call and must never record a word of
  // it. Provider names and §31 codes are labels, not content.
  const { log, lines } = capturingLog();
  const primary = leg(RATE_LIMITED);

  await assertRejects(() => chain({ primary, fallback: null, log })(INPUT));

  const serialised = JSON.stringify(lines);

  assert(!serialised.includes("850"), "an amount reached the log");
  assert(!serialised.includes("فاتورة"), "document text reached the log");
  assert(!serialised.includes(INPUT.ocrText));
  assertEquals(
    Object.keys(lines[0].fields).sort(),
    [
      "error_code",
      "failed_over",
      "failover_skipped",
      "primary_error_code",
      "provider",
      "request_id",
    ],
    "an unexpected field appeared — check it carries no content",
  );
});
