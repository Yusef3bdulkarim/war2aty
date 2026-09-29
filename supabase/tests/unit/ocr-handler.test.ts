/**
 * F14, rewired in F20-T13 · Tests for the ocr-document endpoint, end to end
 * with fakes.
 *
 * Same discipline as `analyze-handler.test.ts`: every dependency is injected
 * so these run the real sequence — auth, config, kill switch, the online
 * reading gate, parsing, the OCR pipeline — without Docker or a network. The
 * questions that matter here are the ones specific to this endpoint: does the
 * response carry OCR text and candidates rather than an analysis, and does
 * every reader failure answer the code that tells the app whether it may read
 * the page on the device instead (F20 matrix §1, O2–O10).
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { createOcrHandler } from "../../functions/_shared/analyze/ocr-handler.ts";
import type { ImageOcrPipeline } from "../../functions/_shared/analyze/image-ocr-pipeline.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";
import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import {
  ProviderFailure,
  type ProviderFailureKind,
} from "../../functions/_shared/ai/provider-failure.ts";
import {
  OCR_TEXT,
  REQUEST_ID,
  SESSION_ID,
  testConfig,
  USER_ID,
  validImageRequestBody,
} from "../fixtures/analyze-fixtures.ts";

const VALID_TOKEN = "valid-token";

const CANDIDATES: ExtractedCandidates = {
  dates: [{ raw_text: "2026-08-15", normalized_date: "2026-08-15", is_ambiguous: false }],
  times: [],
  amounts: [{ raw_text: "850.50 جنيه", value: 850.5, currency: "EGP", is_ambiguous: false }],
  phones: [],
  references: [{ raw_text: "رقم الحساب 12345678", value: "12345678", is_ambiguous: true }],
};

interface Harness {
  readonly call: (
    body?: unknown,
    headers?: Record<string, string>,
  ) => Promise<Response>;
  readonly pipelineCalls: { data: Uint8Array; mimeType: string }[];
  /** How many times the pipeline, and so the Gemini client, was built. */
  readonly pipelineBuilds: number[];
  /** The deadline each read was given, in milliseconds. */
  readonly deadlines: number[];
}

interface HarnessOptions {
  readonly config?: Partial<RuntimeConfig>;
  readonly loadConfig?: () => Promise<RuntimeConfig>;
  readonly pipeline?: ImageOcrPipeline;
  readonly createPipeline?: () => ImageOcrPipeline;
}

function successfulPipeline(): ImageOcrPipeline {
  return () => Promise.resolve({ ocrText: OCR_TEXT, candidates: CANDIDATES });
}

function harness(options: HarnessOptions = {}): Harness {
  const pipelineCalls: { data: Uint8Array; mimeType: string }[] = [];
  const pipelineBuilds: number[] = [];
  const deadlines: number[] = [];

  const config = testConfig({ azureOcrEnabled: true, ...options.config });
  const pipeline = options.pipeline ?? successfulPipeline();

  const handler = createEndpoint({
    name: "ocr-document",
    method: "POST",
    handle: createOcrHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: options.loadConfig ?? (() => Promise.resolve(config)),
      createPipeline: options.createPipeline ?? (() => {
        pipelineBuilds.push(1);
        return (input, signal) => {
          pipelineCalls.push(input);
          return pipeline(input, signal);
        };
      }),
      timeoutSignal: (ms) => {
        deadlines.push(ms);
        return new AbortController().signal;
      },
    }),
  });

  return {
    call: (body = validImageRequestBody(), headers = {}) =>
      handler(
        new Request("https://example.test/functions/v1/ocr-document", {
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
    pipelineCalls,
    pipelineBuilds,
    deadlines,
  };
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

/** Runs `fn` with `console.log` captured, returning every structured line. */
async function capturingLogs(fn: () => Promise<unknown>): Promise<Record<string, unknown>[]> {
  const original = console.log;
  const lines: string[] = [];
  console.log = (line: unknown) => lines.push(String(line));
  try {
    await fn();
  } finally {
    console.log = original;
  }
  return lines.flatMap((line) => {
    try {
      return [JSON.parse(line)];
    } catch {
      return [];
    }
  });
}

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("a valid image request returns the OCR text and candidates, not an analysis", async () => {
  const test = harness();
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.schema_version, "2.0");
  assertEquals(body.session_id, SESSION_ID);
  assertEquals(body.ocr_text, OCR_TEXT);
  assertEquals(body.detected_languages, []);
  assertEquals(body.candidates.dates.length, 1);
  assertEquals(body.candidates.amounts[0].value, 850.5);
  // Never an analysis shape — no document_type/status/summary on this wire.
  assertEquals("document_type" in body, false);
  assertEquals("status" in body, false);
});

Deno.test("the pipeline is called once with the decoded image bytes", async () => {
  const test = harness();
  await test.call();

  assertEquals(test.pipelineCalls.length, 1);
  assertEquals(test.pipelineCalls[0].mimeType, "image/jpeg");
  assertEquals(test.pipelineCalls[0].data.length > 0, true);
});

Deno.test("an empty reading is a 200 with empty text, for the app to call poor quality (O2)", async () => {
  const empty = { dates: [], times: [], amounts: [], phones: [], references: [] };
  const test = harness({ pipeline: () => Promise.resolve({ ocrText: "", candidates: empty }) });
  const response = await test.call();

  assertEquals(response.status, 200);
  assertEquals((await response.json()).ocr_text, "");
});

// ── refusals that must happen before the pipeline is called ───────────────

Deno.test("an unauthenticated caller never reaches the pipeline", async () => {
  const test = harness();
  const response = await test.call(validImageRequestBody(), { Authorization: "" });

  assertEquals(response.status, 401);
  assertEquals(await errorCode(response), "UNAUTHORIZED");
  assertEquals(test.pipelineCalls.length, 0);
});

Deno.test("an invalid token is 401 and never reaches the pipeline", async () => {
  const test = harness();
  const response = await test.call(validImageRequestBody(), {
    Authorization: "Bearer forged",
  });

  assertEquals(response.status, 401);
  assertEquals(test.pipelineCalls.length, 0);
});

Deno.test("the kill switch stops OCR with 503 before anything is parsed", async () => {
  const test = harness({ config: { analysisEnabled: false } });
  const response = await test.call("not even json");

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
  assertEquals(test.pipelineCalls.length, 0);
});

Deno.test("online reading switched off answers OCR_UNAVAILABLE, so the app reads on the device (O10)", async () => {
  // The app only calls this endpoint after choosing the online route; the
  // flag went off since. F14 refused this as INVALID_REQUEST, which left the
  // user an error page for a page the phone can still read.
  const test = harness({ config: { azureOcrEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 502);
  assertEquals(await errorCode(response), "OCR_UNAVAILABLE");
  assertEquals(test.pipelineBuilds.length, 0, "Gemini must not be built, let alone called");
});

Deno.test("malformed JSON is INVALID_REQUEST and never reaches the pipeline", async () => {
  const test = harness();
  const response = await test.call("{ not json");

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(test.pipelineCalls.length, 0);
});

Deno.test("a text-shaped body is refused — this endpoint only serves the image shape", async () => {
  const test = harness();
  const response = await test.call({
    schema_version: "2.0",
    session_id: SESSION_ID,
    installation_id: "9c858901-8a57-4791-81fe-4c455b099bc9",
    app_version: "1.0.0",
    input_type: "text",
    ocr_text: OCR_TEXT,
    detected_languages: ["ar"],
    candidates: { dates: [], times: [], amounts: [], phones: [], references: [] },
  });

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(test.pipelineCalls.length, 0);
});

Deno.test("a config read failure is 500, not a silent fallback to enabled", async () => {
  const test = harness({ loadConfig: () => Promise.reject(ApiError.internalError()) });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
  assertEquals(test.pipelineCalls.length, 0);
});

// ── reader failures (F20 matrix §1, O3–O6) ────────────────────────────────

const OCR_WIRE: Record<ProviderFailureKind, { status: number; code: string }> = {
  rate_limited: { status: 429, code: "AI_RATE_LIMITED" }, // O3
  timeout: { status: 408, code: "TIMEOUT" }, // O4
  upstream_unavailable: { status: 502, code: "OCR_UNAVAILABLE" }, // O5
  network: { status: 502, code: "OCR_UNAVAILABLE" }, // O5
  invalid_output: { status: 502, code: "OCR_UNAVAILABLE" }, // O5
  auth: { status: 500, code: "INTERNAL_ERROR" }, // O6
  bad_request: { status: 500, code: "INTERNAL_ERROR" }, // O6
};

for (const [kind, wire] of Object.entries(OCR_WIRE)) {
  Deno.test(`a reader ${kind} answers ${wire.status} ${wire.code}`, async () => {
    const test = harness({
      pipeline: () => Promise.reject(new ProviderFailure(kind as ProviderFailureKind)),
    });
    const response = await test.call();

    assertEquals(response.status, wire.status);
    assertEquals(await errorCode(response), wire.code);
  });
}

Deno.test("a missing GEMINI_* credential is INTERNAL_ERROR, never OCR_UNAVAILABLE (O6)", async () => {
  // A deploy fault must not quietly send every user down the device path.
  const test = harness({
    createPipeline: () => {
      throw new Error("GEMINI_API_KEY is not set.");
    },
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
});

Deno.test("an unexpected crash mid-read is INTERNAL_ERROR, never the raw message", async () => {
  const test = harness({
    pipeline: () => Promise.reject(new TypeError("undefined is not a function")),
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  const body = await response.json();
  assertEquals(body.error.code, "INTERNAL_ERROR");
  assertEquals(JSON.stringify(body).includes("undefined is not"), false);
});

// ── the deadline (§2) ─────────────────────────────────────────────────────

Deno.test("the single Gemini attempt gets the whole configured deadline", async () => {
  const test = harness({ config: { aiTimeoutSeconds: 25 } });
  await test.call();

  assertEquals(test.deadlines, [25_000]);
  assertEquals(test.pipelineCalls.length, 1, "one attempt, no retry");
});

// ── logs (§51) ────────────────────────────────────────────────────────────

Deno.test("a failed read is logged with its kind and code, never the document", async () => {
  const test = harness({
    pipeline: () => Promise.reject(new ProviderFailure("upstream_unavailable")),
  });

  const lines = await capturingLogs(() => test.call());
  const failed = lines.find((line) => line.event === "ocr.failed");

  assert(failed !== undefined, "no ocr.failed line");
  assertEquals(failed.failure, "upstream_unavailable");
  assertEquals(failed.error_code, "OCR_UNAVAILABLE");
  const serialised = JSON.stringify(lines);
  assertEquals(serialised.includes(OCR_TEXT), false);
  assertEquals(serialised.includes("850"), false);
});
