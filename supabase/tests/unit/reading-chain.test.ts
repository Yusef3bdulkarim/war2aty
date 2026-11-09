/**
 * F36-T07 · Tests for the reading chain.
 *
 * Driven through a fake `fetch` rather than through fake legs: the chain's
 * claim is that each leg is a REAL `createGeminiOcrClient` bound to a
 * different model id, and only a test that sees the URLs can check that. The
 * generic routing underneath is already pinned by `leg-chain.test.ts`; what
 * is tested here is the Gemini-shaped wiring on top of it and the §31 codes
 * the reading stage can produce.
 *
 * Entirely offline: no key, no network, no real clock, and no real timer.
 */

import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { GEMINI_BASE_URL } from "../../functions/_shared/ai/gemini-config.ts";
import {
  createReadingChain,
  DEFAULT_READ_ATTEMPT_CAP_MS,
  DEFAULT_READ_MIN_FALLBACK_MS,
  DEFAULT_READ_STAGE_SECONDS,
  MAX_READING_LEGS,
  READ_EVENT,
  type ReadingChainOptions,
} from "../../functions/_shared/ai/reading-chain.ts";
import { PROVIDER_FAILURE_KINDS } from "../../functions/_shared/ai/provider-failure.ts";

/** The order D1-bis settled, used verbatim so the test records it too. */
const MODELS = ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-3.5-flash"] as const;

const GEMINI = { baseUrl: GEMINI_BASE_URL, apiKey: "test-key", model: "ignored-by-the-chain" };
const IMAGE = {
  bytes: new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]),
  mimeType: "image/jpeg",
};
const REQUEST_ID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";

/** The page text a leg "reads", used to prove it never reaches a log. */
const READING = "فاتورة كهرباء بمبلغ 850 جنيه";

// ── fakes ─────────────────────────────────────────────────────────────────

/** What one leg's HTTP call does. `elapseMs` is how long it "took". */
type LegOutcome =
  | { readonly reads: string }
  /** 429, 5xx, 401, 400 … — whatever `providerFailureForStatus` makes of it. */
  | { readonly status: number }
  /** A dropped connection: `network`. */
  | { readonly drops: true }
  /** Our own budget running out: `timeout`. */
  | { readonly timesOut: true }
  /** A 200 the reader cannot use: `invalid_output`. */
  | { readonly blocked: true };

interface LegSpec {
  readonly outcome: LegOutcome;
  readonly elapseMs?: number;
}

/** A clock the fake fetch advances by hand, so no test waits on real time. */
function fakeClock(startMs = 1_700_000_000_000) {
  let current = startMs;
  return {
    now: () => current,
    advance: (ms: number) => {
      current += ms;
    },
  };
}

type LoggedEvent = { event: string; fields: Record<string, unknown> };

function respond(outcome: LegOutcome): Promise<Response> {
  if ("drops" in outcome) return Promise.reject(new TypeError("connection reset"));
  if ("timesOut" in outcome) {
    return Promise.reject(new DOMException("Deadline exceeded.", "TimeoutError"));
  }
  const body = "blocked" in outcome
    ? { promptFeedback: { blockReason: "SAFETY" } }
    : "reads" in outcome
    ? { candidates: [{ content: { parts: [{ text: outcome.reads }] }, finishReason: "STOP" }] }
    : {};
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status: "status" in outcome ? outcome.status : 200,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

/**
 * A chain over `specs.length` legs, each answering for its own model id. The
 * fake `fetch` dispatches on the URL, which is the only thing that tells the
 * legs apart — exactly as it is in production.
 */
function setup(specs: readonly LegSpec[], overrides: Partial<ReadingChainOptions> = {}) {
  const clock = fakeClock();
  const models = MODELS.slice(0, specs.length);
  const urls: string[] = [];
  const keys: (string | undefined)[] = [];
  const budgets: number[] = [];
  const lines: LoggedEvent[] = [];

  const fetchImpl: typeof fetch = (input, init) => {
    const url = String(input);
    urls.push(url);
    keys.push(new Headers(init?.headers).get("x-goog-api-key") ?? undefined);
    const index = models.findIndex((model) => url.includes(`/models/${model}:`));
    assert(index >= 0, `an unexpected model was called: ${url}`);
    const spec = specs[index];
    clock.advance(spec.elapseMs ?? 0);
    return respond(spec.outcome);
  };

  const chain = createReadingChain({
    gemini: GEMINI,
    models: [...models],
    requestId: REQUEST_ID,
    fetchImpl,
    now: clock.now,
    timeoutSignal: (ms: number) => {
      budgets.push(ms);
      return new AbortController().signal;
    },
    log: (event: string, fields: Record<string, unknown> = {}) => {
      lines.push({ event, fields });
    },
    ...overrides,
  });

  return { chain, clock, urls, keys, budgets, lines };
}

function urlFor(model: string): string {
  return `${GEMINI_BASE_URL}/models/${model}:generateContent`;
}

async function failureCode(run: () => Promise<unknown>): Promise<string> {
  const thrown = await assertRejects(run, ApiError);
  return (thrown as ApiError).code;
}

// ── the shape of the chain ────────────────────────────────────────────────

Deno.test("the chain is three Gemini ids on one key, and builds no new client", async () => {
  // D1-bis's whole answer: a leg is a model id, not a provider. One key, three
  // buckets — which is also why this buys burst headroom and not diversity.
  const { chain, urls, keys } = setup([
    { outcome: { status: 429 } },
    { outcome: { status: 429 } },
    { outcome: { reads: READING } },
  ]);

  await chain(IMAGE);

  assertEquals(urls, [urlFor(MODELS[0]), urlFor(MODELS[1]), urlFor(MODELS[2])]);
  assertEquals(keys, ["test-key", "test-key", "test-key"], "one key behind all three legs");
});

Deno.test("the ids are the caller's, and the shared options' model is ignored", async () => {
  // `GeminiOptions.model` is what `geminiOptionsFromEnv` read for
  // `ocr-document`'s single attempt. The chain must never read a page with it.
  const { chain, urls } = setup([{ outcome: { reads: READING } }]);

  await chain(IMAGE);

  assertEquals(urls, [urlFor(MODELS[0])]);
  assert(!urls[0].includes("ignored-by-the-chain"));
});

// ── each leg succeeding ───────────────────────────────────────────────────

Deno.test("leg 1 reading the page stops the chain there", async () => {
  const { chain, urls, lines } = setup([
    { outcome: { reads: READING } },
    { outcome: { reads: "second" } },
    { outcome: { reads: "third" } },
  ]);

  assertEquals((await chain(IMAGE)).text, READING);
  assertEquals(urls.length, 1, "no leg is called speculatively");
  assertEquals(lines[0].fields.provider, "gemini_read_1");
  assertEquals(lines[0].fields.failed_over, false);
});

Deno.test("leg 2 reads the page when leg 1's bucket is spent", async () => {
  const { chain, urls, lines } = setup([
    { outcome: { status: 429 }, elapseMs: 200 },
    { outcome: { reads: READING } },
    { outcome: { reads: "third" } },
  ]);

  assertEquals((await chain(IMAGE)).text, READING);
  assertEquals(urls, [urlFor(MODELS[0]), urlFor(MODELS[1])]);
  assertEquals(lines[0].fields.provider, "gemini_read_2");
  assertEquals(lines[0].fields.primary_failure, "rate_limited");
});

Deno.test("leg 3 reads the page when both lite buckets are spent", async () => {
  // The minute-rate case T03 identified: 15 RPM per model, so a burst is what
  // reaches leg 3, not the 1,500-a-day ceiling.
  const { chain, urls, lines } = setup([
    { outcome: { status: 429 }, elapseMs: 200 },
    { outcome: { status: 429 }, elapseMs: 200 },
    { outcome: { reads: READING } },
  ]);

  assertEquals((await chain(IMAGE)).text, READING);
  assertEquals(urls.length, 3);
  assertEquals(lines[0].fields.provider, "gemini_read_3");
  assertEquals(lines[0].fields.failed_over, true);
});

// ── each eligible failure failing over (matrix rows O3–O5) ────────────────

for (
  const [name, outcome, kind] of [
    ["a 429 fails over", { status: 429 }, "rate_limited"],
    ["a 5xx fails over", { status: 503 }, "upstream_unavailable"],
    ["a dropped connection fails over", { drops: true }, "network"],
    ["our budget running out fails over", { timesOut: true }, "timeout"],
    ["a blocked or unusable answer fails over", { blocked: true }, "invalid_output"],
  ] as const
) {
  Deno.test(name, async () => {
    const { chain, urls, lines } = setup([
      { outcome, elapseMs: 200 },
      { outcome: { reads: READING } },
    ]);

    assertEquals((await chain(IMAGE)).text, READING);
    assertEquals(urls.length, 2);
    assertEquals(lines[0].fields.primary_failure, kind);
  });
}

// ── what must NOT fail over (matrix row O6) ───────────────────────────────

for (
  const [name, status] of [
    ["a revoked key (401) does NOT fail over", 401],
    ["a forbidden key (403) does NOT fail over", 403],
    ["a retired or misspelled model id (404) does NOT fail over", 404],
    ["a malformed request (400) does NOT fail over", 400],
  ] as const
) {
  Deno.test(name, async () => {
    // Our own deploy fault. Trying the next id would serve the request and
    // hide the misconfiguration until a bucket ran out too — and a retired id
    // is precisely what T03 found had happened to both 2.5 models.
    const { chain, urls, lines } = setup([
      { outcome: { status }, elapseMs: 200 },
      { outcome: { reads: READING } },
      { outcome: { reads: "third" } },
    ]);

    assertEquals(await failureCode(() => chain(IMAGE)), "INTERNAL_ERROR");
    assertEquals(urls.length, 1, "a config fault must not be retried on another id");
    assertEquals(lines[0].fields.failover_skipped, "not_fallback_eligible");
  });
}

Deno.test("an ineligible failure on the SECOND leg stops the chain before the third", async () => {
  const { chain, urls } = setup([
    { outcome: { status: 429 }, elapseMs: 200 },
    { outcome: { status: 401 }, elapseMs: 200 },
    { outcome: { reads: "third" } },
  ]);

  assertEquals(await failureCode(() => chain(IMAGE)), "INTERNAL_ERROR");
  assertEquals(urls.length, 2);
});

// ── when every leg fails ──────────────────────────────────────────────────

for (
  const [name, last, code] of [
    ["three spent buckets answer AI_RATE_LIMITED", { status: 429 }, "AI_RATE_LIMITED"],
    ["an outage on the last leg answers ANALYSIS_FAILED", { status: 503 }, "ANALYSIS_FAILED"],
    ["a dropped connection answers ANALYSIS_FAILED", { drops: true }, "ANALYSIS_FAILED"],
    ["an unusable last reading answers ANALYSIS_FAILED", { blocked: true }, "ANALYSIS_FAILED"],
    ["running out of time answers TIMEOUT", { timesOut: true }, "TIMEOUT"],
  ] as const
) {
  Deno.test(name, async () => {
    // Whatever the code, the client speaks it as «جرب كمان شوية»: with no
    // on-device reader left after F39, a failed read has no other answer.
    const { chain, urls, lines } = setup([
      { outcome: { status: 429 }, elapseMs: 100 },
      { outcome: { status: 429 }, elapseMs: 100 },
      { outcome: last, elapseMs: 100 },
    ]);

    assertEquals(await failureCode(() => chain(IMAGE)), code);
    assertEquals(urls.length, 3, "every leg was given its chance");
    assertEquals(lines.length, 1, "one line per stage");
    assertEquals(lines[0].fields.provider, "gemini_read_3");
    assertEquals(lines[0].fields.error_code, code);
  });
}

Deno.test("no reading failure can produce OCR_UNAVAILABLE (trap #3)", async () => {
  // That code tells the app it may read on the device instead. After F39 there
  // is no on-device reader, so emitting it would be an instruction the client
  // cannot follow. Driven off the closed kind list, so a kind added later
  // fails this test rather than slipping through.
  const outcomes: Record<string, LegOutcome> = {
    rate_limited: { status: 429 },
    upstream_unavailable: { status: 503 },
    timeout: { timesOut: true },
    network: { drops: true },
    invalid_output: { blocked: true },
    auth: { status: 401 },
    bad_request: { status: 400 },
  };

  for (const kind of PROVIDER_FAILURE_KINDS) {
    const outcome = outcomes[kind];
    assert(outcome !== undefined, `no probe for the kind ${kind}`);
    const { chain } = setup([{ outcome, elapseMs: 100 }]);

    const code = await failureCode(() => chain(IMAGE));
    assert(code !== "OCR_UNAVAILABLE", `${kind} reached OCR_UNAVAILABLE`);
  }
});

// ── an empty reading is an answer, not a failure (matrix row O2) ──────────

Deno.test("a blank page is returned as an empty reading, and spends no second leg", async () => {
  // F20's rule, kept: a blank page really is blank. What `explain-document`
  // can do with nothing to explain is T15's question, not the chain's.
  const { chain, urls } = setup([
    { outcome: { reads: "   " } },
    { outcome: { reads: READING } },
  ]);

  assertEquals((await chain(IMAGE)).text, "");
  assertEquals(urls.length, 1);
});

// ── time: three legs inside D4's ten seconds ──────────────────────────────

Deno.test("the stage's defaults are the D4 split and a cap three legs fit inside", () => {
  assertEquals(DEFAULT_READ_STAGE_SECONDS, 10, "D4: 30 s split 10 s read / 20 s explain");
  assertEquals(DEFAULT_READ_ATTEMPT_CAP_MS, 4_000);
  assertEquals(DEFAULT_READ_MIN_FALLBACK_MS, 2_000);
  assertEquals(
    2 * DEFAULT_READ_ATTEMPT_CAP_MS + DEFAULT_READ_MIN_FALLBACK_MS,
    DEFAULT_READ_STAGE_SECONDS * 1000,
    "two hung legs must still leave exactly the floor for the third",
  );
});

Deno.test("every leg hanging to its cap still leaves leg 3 its chance", async () => {
  // The reason the stage does not reuse the analysis chain's 18 s cap: inside
  // a 10 s budget that cap would let leg 1 eat the stage and make legs 2 and 3
  // decorative.
  const { chain, urls, budgets } = setup([
    { outcome: { timesOut: true }, elapseMs: DEFAULT_READ_ATTEMPT_CAP_MS },
    { outcome: { timesOut: true }, elapseMs: DEFAULT_READ_ATTEMPT_CAP_MS },
    { outcome: { reads: READING } },
  ]);

  assertEquals((await chain(IMAGE)).text, READING);
  assertEquals(urls.length, 3);
  assertEquals(budgets, [
    DEFAULT_READ_ATTEMPT_CAP_MS,
    DEFAULT_READ_ATTEMPT_CAP_MS,
    DEFAULT_READ_MIN_FALLBACK_MS,
  ]);
});

Deno.test("a slow first read leaves the next one only what genuinely remains", async () => {
  const { chain, budgets } = setup([
    { outcome: { status: 429 }, elapseMs: 7_000 },
    { outcome: { reads: READING } },
  ]);

  await chain(IMAGE);

  assertEquals(budgets, [DEFAULT_READ_ATTEMPT_CAP_MS, 3_000], "10 s − 7 s elapsed");
});

Deno.test("too little left for another read ends the stage", async () => {
  const { chain, urls } = setup([
    { outcome: { status: 429 }, elapseMs: 8_001 },
    { outcome: { reads: READING } },
  ]);

  assertEquals(await failureCode(() => chain(IMAGE)), "AI_RATE_LIMITED");
  assertEquals(urls.length, 1, "1,999 ms is below the floor");
});

// ── what the chain refuses to be built with ───────────────────────────────

Deno.test("a chain with no model ids is refused when it is built", () => {
  assertThrows(
    () => createReadingChain({ gemini: GEMINI, models: [], requestId: REQUEST_ID }),
    RangeError,
  );
});

Deno.test("a fourth model id is refused: there is no fourth name for the log", () => {
  assertEquals(MAX_READING_LEGS, 3);
  assertThrows(
    () =>
      createReadingChain({
        gemini: GEMINI,
        models: [...MODELS, "gemini-3.8-flash"],
        requestId: REQUEST_ID,
      }),
    RangeError,
  );
});

Deno.test("a blank model id is refused rather than read with", () => {
  // An unset env var trimmed to "" would otherwise build a leg whose URL is
  // `/models/:generateContent` and 404 on every photo.
  assertThrows(
    () => createReadingChain({ gemini: GEMINI, models: [MODELS[0], "  "], requestId: REQUEST_ID }),
    RangeError,
  );
});

// ── the log (§7, §51) ─────────────────────────────────────────────────────

Deno.test("the stage logs one line, under its own event", async () => {
  // Two chains run inside one request; a shared event name would make the log
  // unable to say which stage burned the quota.
  const { chain, lines } = setup([
    { outcome: { status: 429 }, elapseMs: 100 },
    { outcome: { reads: READING } },
  ]);

  await chain(IMAGE);

  assertEquals(lines.length, 1);
  assertEquals(lines[0].event, READ_EVENT);
  assertEquals(lines[0].fields.request_id, REQUEST_ID);
});

Deno.test("the log never carries the image, the reading or the key", async () => {
  const { chain, lines } = setup([
    { outcome: { status: 429 }, elapseMs: 100 },
    { outcome: { status: 429 }, elapseMs: 100 },
    { outcome: { reads: READING } },
  ]);

  await chain(IMAGE);

  const serialised = JSON.stringify(lines);
  assert(!serialised.includes("850"), "an amount reached the log");
  assert(!serialised.includes("فاتورة"), "document text reached the log");
  assert(!serialised.includes("test-key"), "the API key reached the log");
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
