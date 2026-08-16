/**
 * F14 · Tests for the ocr-document endpoint, end to end with fakes.
 *
 * Same discipline as `analyze-handler.test.ts`: every dependency is injected
 * so these run the real sequence — auth, config, kill switch, dark-launch
 * gate, parsing, the image pipeline — without Docker, a network, or an Azure
 * bill. The questions that matter here are the ones specific to this split:
 * does this endpoint ever reserve a quota slot, does it ever call Groq, and
 * does the response carry OCR text/candidates rather than an analysis.
 */

import { assertEquals } from "jsr:@std/assert@1";

import { createOcrHandler } from "../../functions/_shared/analyze/ocr-handler.ts";
import type { ImageAnalysisPipeline } from "../../functions/_shared/analyze/image-analysis-pipeline.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";
import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
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
  readonly pipelineTimeouts: number[];
}

interface HarnessOptions {
  readonly config?: Partial<RuntimeConfig>;
  readonly loadConfig?: () => Promise<RuntimeConfig>;
  readonly pipeline?: ImageAnalysisPipeline;
}

function successfulPipeline(): ImageAnalysisPipeline {
  return () =>
    Promise.resolve({
      ocrText: OCR_TEXT,
      candidates: CANDIDATES,
      // The OCR-only endpoint never consults verification — it has nothing to
      // decide with it, since it never builds phones/references on the wire.
      verification: {
        dates: [],
        times: [],
        amounts: [],
        phones: [],
        references: [],
        needsUserReview: false,
      },
    });
}

function harness(options: HarnessOptions = {}): Harness {
  const pipelineCalls: { data: Uint8Array; mimeType: string }[] = [];
  const pipelineTimeouts: number[] = [];

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
      createImagePipeline: (timeoutSeconds) => {
        pipelineTimeouts.push(timeoutSeconds);
        return (input) => {
          pipelineCalls.push(input);
          return pipeline(input);
        };
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
    pipelineTimeouts,
  };
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
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

Deno.test("azureOcrEnabled dark refuses the request as INVALID_REQUEST, same as analyze-document", async () => {
  const test = harness({ config: { azureOcrEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(test.pipelineCalls.length, 0);
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

// ── failures propagate; nothing here silently falls back to offline ───────

Deno.test("a failed read propagates its status rather than falling back to a text analysis", async () => {
  const test = harness({ pipeline: () => Promise.reject(ApiError.timeout()) });
  const response = await test.call();

  assertEquals(response.status, 408);
  assertEquals(await errorCode(response), "TIMEOUT");
});

Deno.test("an unexpected crash mid-read is INTERNAL_ERROR, never the raw message", async () => {
  const test = harness({
    pipeline: () => Promise.reject(new TypeError("undefined is not a function")),
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
});

Deno.test("the configured timeout reaches the pipeline builder", async () => {
  const test = harness({ config: { aiTimeoutSeconds: 25 } });
  await test.call();

  assertEquals(test.pipelineTimeouts, [25]);
});
