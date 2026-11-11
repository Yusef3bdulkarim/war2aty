/**
 * F36-T15 · Tests for the explain-document handler, end to end with fakes.
 *
 * Every dependency is injected, so these run the REAL sequence — auth, config,
 * both gates, parsing, reservation, reading, explaining, grounding, response
 * building — without Docker, a network, or an AI bill.
 *
 * The questions being asked are the ones that cost money or trust: does an
 * unauthenticated caller ever reach the AI, does a failed stage release the
 * slot, and does the reading ever escape into the response (trap #4).
 */

import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";

import { createExplainHandler } from "../../functions/_shared/explain/explain-handler.ts";
import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import type { GeminiOcrResult, OcrImage } from "../../functions/_shared/ai/gemini-ocr-client.ts";
import type { ReadingChain } from "../../functions/_shared/ai/reading-chain.ts";
import type { ExplainChain } from "../../functions/_shared/ai/explain-chain.ts";
import type { ExplainPromptInput } from "../../functions/_shared/prompts/explain-prompt.ts";
import type { ModelExplanation } from "../../functions/_shared/schemas/explain-output.schema.ts";
import type {
  FinalizeResult,
  ReservationResult,
  ReserveInput,
  ReserveOutcome,
  SlotStore,
} from "../../functions/_shared/usage/slot-reservation.ts";
import {
  INSTALLATION_ID,
  SESSION_ID,
  testConfig,
  validExplainBody,
} from "../fixtures/explain-fixtures.ts";

const VALID_TOKEN = "valid-token";
const USER_ID = "test-user-uuid";
const REQUEST_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
const NOW = new Date("2026-11-10T14:00:00Z");

const READING_TEXT =
  "شركة الكهربا\nإيصال كهربا\nالمبلغ المطلوب: 350 جنيه\nأخر ميعاد للسداد: 2026-12-15";

function modelExplanation(overrides: Partial<ModelExplanation> = {}): ModelExplanation {
  return {
    status: "success",
    paper: { title: "فاتورة الكهربا" },
    explain: ["دي فاتورة كهربا وعليها مبلغ لازم يتدفع."],
    todo: { required: true, text: "ادفع 350 جنيه قبل 2026-12-15." },
    date: { date: "2026-12-15", time: null, text: "آخر ميعاد للسداد" },
    caution: null,
    contact: null,
    place: null,
    ...overrides,
  };
}

interface Harness {
  readonly call: (
    body?: unknown,
    headers?: Record<string, string>,
  ) => Promise<Response>;
  readonly reserves: ReserveInput[];
  readonly finalizes: { requestId: string; success: boolean; errorCode?: string }[];
  readonly readImages: OcrImage[];
  readonly explainInputs: ExplainPromptInput[];
  readonly readerStageSeconds: number[];
  readonly explainerStageSeconds: number[];
}

interface HarnessOptions {
  readonly config?: Partial<RuntimeConfig>;
  readonly reserveOutcome?: ReserveOutcome;
  readonly readResult?: GeminiOcrResult;
  readonly readError?: Error;
  readonly explainResult?: ModelExplanation;
  readonly explainError?: Error;
  readonly loadConfig?: () => Promise<RuntimeConfig>;
}

function createHarness(options: HarnessOptions = {}): Harness {
  const reserves: ReserveInput[] = [];
  const finalizes: { requestId: string; success: boolean; errorCode?: string }[] = [];
  const readImages: OcrImage[] = [];
  const explainInputs: ExplainPromptInput[] = [];
  const readerStageSeconds: number[] = [];
  const explainerStageSeconds: number[] = [];

  const config = testConfig({ explainEnabled: true, ...options.config });

  const slots: SlotStore = {
    reserve(input: ReserveInput): Promise<ReservationResult> {
      reserves.push(input);
      return Promise.resolve({
        outcome: options.reserveOutcome ?? "reserved",
        usedToday: 0,
        reservedToday: 1,
      });
    },
    finalize(requestId, success, errorCode): Promise<FinalizeResult> {
      finalizes.push({ requestId, success, errorCode });
      return Promise.resolve({
        outcome: success ? "succeeded" : "released",
        usedToday: success ? 1 : 0,
        reservedToday: 0,
      });
    },
  };

  const handler = createEndpoint({
    name: "explain-document",
    method: "POST",
    handle: createExplainHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: options.loadConfig ?? (() => Promise.resolve(config)),
      slots,
      createReader: (stageSeconds: number, _requestId: string): ReadingChain => {
        readerStageSeconds.push(stageSeconds);
        return (image: OcrImage) => {
          readImages.push(image);
          if (options.readError) return Promise.reject(options.readError);
          return Promise.resolve(
            options.readResult ?? { text: READING_TEXT },
          );
        };
      },
      createExplainer: (stageSeconds: number, _requestId: string): ExplainChain => {
        explainerStageSeconds.push(stageSeconds);
        return (input: ExplainPromptInput) => {
          explainInputs.push(input);
          if (options.explainError) return Promise.reject(options.explainError);
          return Promise.resolve(
            options.explainResult ?? modelExplanation(),
          );
        };
      },
      hashInstallation: (id) => Promise.resolve(`hashed:${id.slice(0, 4)}`),
      now: () => NOW,
    }),
  });

  return {
    call: (body = validExplainBody(), headers = {}) =>
      handler(
        new Request("https://example.test/functions/v1/explain-document", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${VALID_TOKEN}`,
            "Content-Type": "application/json",
            "x-request-id": REQUEST_ID,
            ...headers,
          },
          body: typeof body === "string" ? body : JSON.stringify(body),
        }),
      ),
    reserves,
    finalizes,
    readImages,
    explainInputs,
    readerStageSeconds,
    explainerStageSeconds,
  };
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

// ── the happy path ──────────────────────────────────────────────────────

Deno.test("a valid explain returns the §33 body and consumes one slot", async () => {
  const test = createHarness();
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.explain_schema_version, "1.0");
  assertEquals(body.session_id, SESSION_ID);
  assertEquals(body.status, "success");
  assertEquals(body.paper.title, "فاتورة الكهربا");
  assert(Array.isArray(body.explain));
  assert(body.todo.text.length > 0);

  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, true);
});

Deno.test("the reservation uses explainDailyLimit, not dailyLimit", async () => {
  const test = createHarness({ config: { explainDailyLimit: 7, dailyLimit: 3 } });
  await test.call();

  assertEquals(test.reserves[0].dailyLimit, 7);
});

Deno.test("the slot outlives the explain timeout so a slow success is not swept", async () => {
  const test = createHarness({ config: { explainTimeoutSeconds: 30 } });
  await test.call();

  assert(
    test.reserves[0].ttlSeconds > 30,
    "a slot that expires before the budget does would be swept mid-request",
  );
});

Deno.test("the reading chain receives 10 s and the explain chain receives the rest", async () => {
  const test = createHarness({ config: { explainTimeoutSeconds: 30 } });
  await test.call();

  assertEquals(test.readerStageSeconds, [10]);
  assertEquals(test.explainerStageSeconds, [20]);
});

Deno.test("a larger timeout gives the extra time to the explain stage", async () => {
  const test = createHarness({ config: { explainTimeoutSeconds: 45 } });
  await test.call();

  assertEquals(test.readerStageSeconds, [10]);
  assertEquals(test.explainerStageSeconds, [35]);
});

Deno.test("the raw installation id is never handed to the store", async () => {
  const test = createHarness();
  await test.call();

  const hash = test.reserves[0].installationHash;
  assert(hash.startsWith("hashed:"), "the store must receive a hash");
  assert(!hash.includes(INSTALLATION_ID), "the raw id must never be stored");
});

Deno.test("the reading is passed to the explain chain as readingText", async () => {
  const test = createHarness();
  await test.call();

  assertEquals(test.explainInputs.length, 1);
  assertEquals(test.explainInputs[0].readingText, READING_TEXT);
});

// ── the reading never leaks (trap #4) ───────────────────────────────────

Deno.test("the response body contains no substring of the reading", async () => {
  const test = createHarness();
  const response = await test.call();
  const text = await response.text();

  for (const line of READING_TEXT.split("\n")) {
    assert(
      !text.includes(line),
      `reading leaked into response: "${line}"`,
    );
  }
});

// ── auth gate ───────────────────────────────────────────────────────────

Deno.test("no token → 401 UNAUTHORIZED, no slot reserved", async () => {
  const test = createHarness();
  const response = await test.call(undefined, { Authorization: "" });

  assertEquals(response.status, 401);
  assertEquals(await errorCode(response), "UNAUTHORIZED");
  assertEquals(test.reserves.length, 0);
});

Deno.test("invalid token → 401 UNAUTHORIZED", async () => {
  const test = createHarness();
  const response = await test.call(undefined, { Authorization: "Bearer bad-token" });

  assertEquals(response.status, 401);
  assertEquals(await errorCode(response), "UNAUTHORIZED");
  assertEquals(test.reserves.length, 0);
});

// ── analysisEnabled gate (trap #3: checked first) ───────────────────────

Deno.test("analysisEnabled=false → 503 ANALYSIS_DISABLED, no slot reserved", async () => {
  const test = createHarness({ config: { analysisEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
  assertEquals(test.reserves.length, 0);
});

// ── explainEnabled gate ─────────────────────────────────────────────────

Deno.test("explainEnabled=false → 503 ANALYSIS_DISABLED, no slot reserved", async () => {
  const test = createHarness({ config: { explainEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
  assertEquals(test.reserves.length, 0);
});

Deno.test("analysisEnabled=true + explainEnabled=false → still 503", async () => {
  const test = createHarness({
    config: { analysisEnabled: true, explainEnabled: false },
  });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
});

// ── parse gate ──────────────────────────────────────────────────────────

Deno.test("malformed JSON → 400 INVALID_REQUEST, no slot reserved", async () => {
  const test = createHarness();
  const response = await test.call("not-json");

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(test.reserves.length, 0);
});

Deno.test("an analyze-document body (with schema_version) → 400 INVALID_REQUEST", async () => {
  const test = createHarness();
  const response = await test.call({
    schema_version: "2.0",
    session_id: SESSION_ID,
    installation_id: INSTALLATION_ID,
    app_version: "1.0.0",
    input_type: "text",
    ocr_text: "test",
    detected_languages: ["ar"],
    candidates: {},
  });

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
});

// ── daily limit ─────────────────────────────────────────────────────────

Deno.test("limit_reached → 429 DAILY_LIMIT_REACHED with reset_at", async () => {
  const test = createHarness({ reserveOutcome: "limit_reached" });
  const response = await test.call();

  assertEquals(response.status, 429);
  assertEquals(await errorCode(response.clone()), "DAILY_LIMIT_REACHED");
  const body = await response.json();
  assert(body.error.details.reset_at, "must carry the reset time");
});

// ── global cap ──────────────────────────────────────────────────────────

Deno.test("global_capacity_reached → 429 GLOBAL_CAPACITY_REACHED", async () => {
  const test = createHarness({ reserveOutcome: "global_capacity_reached" });
  const response = await test.call();

  assertEquals(response.status, 429);
  assertEquals(await errorCode(response), "GLOBAL_CAPACITY_REACHED");
});

// ── duplicate request ───────────────────────────────────────────────────

Deno.test("duplicate request id → 500 ANALYSIS_FAILED", async () => {
  const test = createHarness({ reserveOutcome: "duplicate" });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "ANALYSIS_FAILED");
});

// ── read-stage failure releases the slot ────────────────────────────────

Deno.test("a read-stage failure releases the slot and surfaces the error", async () => {
  const test = createHarness({
    readError: ApiError.analysisFailed(),
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "ANALYSIS_FAILED");
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
  assertEquals(test.finalizes[0].errorCode, "ANALYSIS_FAILED");
});

Deno.test("a read-stage timeout releases the slot with TIMEOUT", async () => {
  const test = createHarness({
    readError: new ApiError("TIMEOUT", "Read stage timed out."),
  });
  const response = await test.call();

  assertEquals(response.status, 408);
  assertEquals(await errorCode(response), "TIMEOUT");
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
  assertEquals(test.finalizes[0].errorCode, "TIMEOUT");
});

// ── explain-stage failure releases the slot ─────────────────────────────

Deno.test("an explain-stage failure releases the slot and surfaces the error", async () => {
  const test = createHarness({
    explainError: ApiError.analysisFailed(),
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "ANALYSIS_FAILED");
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
});

Deno.test("an explain-stage rate limit releases the slot with AI_RATE_LIMITED", async () => {
  const test = createHarness({
    explainError: new ApiError("AI_RATE_LIMITED", "Rate limited."),
  });
  const response = await test.call();

  assertEquals(response.status, 429);
  assertEquals(await errorCode(response), "AI_RATE_LIMITED");
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
});

// ── empty reading → unsupported (T07's note) ────────────────────────────

Deno.test("an empty reading short-circuits to unsupported and releases the slot", async () => {
  const test = createHarness({
    readResult: { text: "" },
  });
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "unsupported");
  assertEquals(body.explain_schema_version, "1.0");
  assertEquals(body.session_id, SESSION_ID);

  // The explain chain must NOT have been called.
  assertEquals(test.explainInputs.length, 0);

  // Unsupported releases the slot (§31 rule 6).
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
});

Deno.test("a whitespace-only reading is treated as empty", async () => {
  const test = createHarness({
    readResult: { text: "   \n  " },
  });
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "unsupported");
  assertEquals(test.explainInputs.length, 0);
});

// ── unsupported from the model also releases the slot ───────────────────

Deno.test("model returning unsupported releases the slot", async () => {
  const test = createHarness({
    explainResult: modelExplanation({ status: "unsupported" }),
  });
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "unsupported");

  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
});

// ── the chains are built BEFORE the slot ────────────────────────────────

Deno.test("a credential failure never reserves a slot", async () => {
  const test = createHarness({
    // Simulate createReader throwing due to missing GEMINI_API_KEY.
    config: { explainEnabled: true, analysisEnabled: true },
  });
  // Override the handler to use a reader that throws on construction.
  const handler = createEndpoint({
    name: "explain-document",
    method: "POST",
    handle: createExplainHandler({
      verifyToken: (token: string) =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: () => Promise.resolve(testConfig({ explainEnabled: true })),
      slots: {
        reserve: () => {
          throw new Error("reserve must not be called");
        },
        finalize: () => {
          throw new Error("finalize must not be called");
        },
      },
      createReader: () => {
        throw new Error("GEMINI_API_KEY is not set.");
      },
      createExplainer: () => {
        throw new Error("not reached");
      },
      hashInstallation: (id) => Promise.resolve(`hashed:${id.slice(0, 4)}`),
      now: () => NOW,
    }),
  });

  const response = await handler(
    new Request("https://example.test/functions/v1/explain-document", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${VALID_TOKEN}`,
        "Content-Type": "application/json",
        "x-request-id": REQUEST_ID,
      },
      body: JSON.stringify(validExplainBody()),
    }),
  );

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
});

// ── response builder ────────────────────────────────────────────────────

Deno.test("a title over 24 characters is truncated", async () => {
  const test = createHarness({
    explainResult: modelExplanation({
      paper: { title: "فاتورة كهربا شركة مصر العليا للكهرباء" },
    }),
  });
  const response = await test.call();
  const body = await response.json();

  assert(body.paper.title.length <= 24, `title too long: ${body.paper.title.length}`);
});

Deno.test("a paragraph over 220 characters is truncated", async () => {
  const long = "أ".repeat(250);
  const test = createHarness({
    explainResult: modelExplanation({ explain: [long] }),
  });
  const response = await test.call();
  const body = await response.json();

  assert(body.explain[0].length <= 220, `paragraph too long: ${body.explain[0].length}`);
});

Deno.test("more than 4 paragraphs are trimmed to 4", async () => {
  const test = createHarness({
    explainResult: modelExplanation({
      explain: ["واحد.", "اتنين.", "تلاتة.", "أربعة.", "خمسة.", "ستة."],
    }),
  });
  const response = await test.call();
  const body = await response.json();

  assertEquals(body.explain.length, 4);
});
