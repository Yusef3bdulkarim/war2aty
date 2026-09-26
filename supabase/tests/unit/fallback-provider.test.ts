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
    fallback: fallback.factory,
    totalSeconds: TOTAL_SECONDS,
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
    fallback: fallback.factory,
    totalSeconds: TOTAL_SECONDS,
    now: fakeClock().now,
  })(INPUT);

  assertEquals(fallback.budgets, [], "the fallback was built and should not be");
});

Deno.test("the primary gets its share of the budget", async () => {
  const primary = leg(analysis("primary"));

  await createFallbackAnalysisProvider({
    primary: primary.factory,
    fallback: null,
    totalSeconds: TOTAL_SECONDS,
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
      fallback: fallback.factory,
      totalSeconds: TOTAL_SECONDS,
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
    fallback: fallback.factory,
    totalSeconds: TOTAL_SECONDS,
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
    fallback: fallback.factory,
    totalSeconds: TOTAL_SECONDS,
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
    fallback: fallback.factory,
    totalSeconds: TOTAL_SECONDS,
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
        fallback: fallback.factory,
        totalSeconds: TOTAL_SECONDS,
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
    fallback: fallback.factory,
    totalSeconds: TOTAL_SECONDS,
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
        fallback: fallback.factory,
        totalSeconds: TOTAL_SECONDS,
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
        fallback: fallback.factory,
        totalSeconds: TOTAL_SECONDS,
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
        fallback: null,
        totalSeconds: TOTAL_SECONDS,
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
        fallback: fallback.factory,
        totalSeconds: TOTAL_SECONDS,
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
        fallback: fallback.factory,
        totalSeconds: TOTAL_SECONDS,
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
        fallback: fallback.factory,
        totalSeconds: TOTAL_SECONDS,
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
