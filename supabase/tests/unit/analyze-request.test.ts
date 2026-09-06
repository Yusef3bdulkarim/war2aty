/**
 * F06-T13 · Tests for request validation (§29).
 *
 * The bar is not "does it parse" but "can anything the contract forbids get
 * past it" — an oversized document, a body carrying image data, a candidate
 * array large enough to blow the token budget.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  parseAnalyzeImageRequest,
  parseAnalyzeRequest,
} from "../../functions/_shared/analyze/analyze-request.ts";
import {
  INSTALLATION_ID,
  OCR_TEXT,
  SESSION_ID,
  testConfig,
  VALID_IMAGE_BASE64,
  validCandidates,
  validImageRequestBody,
  validRequestBody,
} from "../fixtures/analyze-fixtures.ts";

const CONFIG = testConfig();

function assertCode(code: string, body: unknown, config = CONFIG): void {
  const error = assertThrows(
    () => parseAnalyzeRequest(body, config),
    ApiError,
  ) as ApiError;
  assertEquals(error.code, code);
}

Deno.test("a valid body parses into the typed request", () => {
  const parsed = parseAnalyzeRequest(validRequestBody(), CONFIG);

  assertEquals(parsed.sessionId, SESSION_ID);
  assertEquals(parsed.installationId, INSTALLATION_ID);
  assertEquals(parsed.appVersion, "1.0.0");
  assertEquals(parsed.ocrText, OCR_TEXT);
  assertEquals(parsed.detectedLanguages, ["ar"]);
  assertEquals(parsed.candidates.dates.length, 1);
  assertEquals(parsed.droppedCandidates, 0);
});

// ── envelope ──────────────────────────────────────────────────────────────

Deno.test("a non-object body is rejected", () => {
  assertCode("INVALID_REQUEST", "just a string");
  assertCode("INVALID_REQUEST", null);
  assertCode("INVALID_REQUEST", [validRequestBody()]);
});

Deno.test("an unknown schema version is UNSUPPORTED_SCHEMA, not INVALID_REQUEST", () => {
  // The client maps these to different failures; conflating them would tell a
  // user their request was malformed when their app is simply out of date.
  // "1.0" is deliberate here: a real pre-F13-T09 client, not a made-up string.
  assertCode("UNSUPPORTED_SCHEMA", validRequestBody({ schema_version: "1.0" }));
});

Deno.test('input_type must be exactly "text" on the text shape (§29 v2)', () => {
  assertCode("INVALID_REQUEST", validRequestBody({ input_type: "image" }));
  assertCode(
    "INVALID_REQUEST",
    validRequestBody({ input_type: undefined as unknown as string }),
  );
});

Deno.test("an unknown property is rejected outright", () => {
  // The privacy tripwire: a client that ever attaches image bytes must be
  // refused, not quietly accepted (§7).
  assertCode(
    "INVALID_REQUEST",
    validRequestBody({ image_base64: "iVBORw0KGgo=" }),
  );
});

Deno.test("an app version below the minimum is UNSUPPORTED_APP_VERSION", () => {
  const config = testConfig({ minimumAppVersion: "1.2.0" });
  assertCode("UNSUPPORTED_APP_VERSION", validRequestBody({ app_version: "1.1.9" }), config);
});

Deno.test("version comparison is numeric, not lexical", () => {
  const config = testConfig({ minimumAppVersion: "1.9.0" });
  // "1.10.0" < "1.9.0" as strings, but 1.10.0 is the newer build.
  const parsed = parseAnalyzeRequest(
    validRequestBody({ app_version: "1.10.0" }),
    config,
  );
  assertEquals(parsed.appVersion, "1.10.0");
});

Deno.test("a malformed app version is INVALID_REQUEST, not an old app", () => {
  // Telling someone to update an app that is already current sends them nowhere.
  assertCode("INVALID_REQUEST", validRequestBody({ app_version: "1.0" }));
  assertCode("INVALID_REQUEST", validRequestBody({ app_version: "v1.0.0" }));
});

Deno.test("session and installation ids must be uuids", () => {
  assertCode("INVALID_REQUEST", validRequestBody({ session_id: "not-a-uuid" }));
  assertCode("INVALID_REQUEST", validRequestBody({ installation_id: "12345" }));
});

// ── ocr text ──────────────────────────────────────────────────────────────

Deno.test("empty and whitespace-only ocr text are rejected", () => {
  assertCode("INVALID_REQUEST", validRequestBody({ ocr_text: "" }));
  // Paying an AI provider to read a page of spaces would be absurd.
  assertCode("INVALID_REQUEST", validRequestBody({ ocr_text: "   \n\t " }));
});

Deno.test("ocr text over the configured cap is rejected", () => {
  const config = testConfig({ maxOcrCharacters: 50 });
  assertCode("INVALID_REQUEST", validRequestBody({ ocr_text: "ا".repeat(51) }), config);

  const parsed = parseAnalyzeRequest(
    validRequestBody({ ocr_text: "ا".repeat(50) }),
    config,
  );
  assertEquals(parsed.ocrText.length, 50);
});

// ── languages ─────────────────────────────────────────────────────────────

Deno.test("unrecognised language tags are dropped, not fatal", () => {
  // A tag is only a hint in the prompt; an OCR engine that starts reporting
  // "ar-EG" must not begin failing analyses.
  const parsed = parseAnalyzeRequest(
    validRequestBody({ detected_languages: ["AR", "ar-EG", "en", 7, "ar"] }),
    CONFIG,
  );
  assertEquals(parsed.detectedLanguages, ["ar", "en"]);
});

Deno.test("a non-array detected_languages is rejected", () => {
  assertCode("INVALID_REQUEST", validRequestBody({ detected_languages: "ar" }));
});

// ── candidates ────────────────────────────────────────────────────────────

Deno.test("a missing candidate array is rejected", () => {
  const candidates = validCandidates();
  delete candidates.times;
  // Absent and empty must not look the same: one is a client bug.
  assertCode("INVALID_REQUEST", validRequestBody({ candidates }));
});

Deno.test("all-empty candidate arrays are valid (§29 rule 6)", () => {
  const parsed = parseAnalyzeRequest(
    validRequestBody({
      candidates: { dates: [], times: [], amounts: [], phones: [], references: [] },
    }),
    CONFIG,
  );
  assertEquals(parsed.candidates.dates, []);
  assertEquals(parsed.droppedCandidates, 0);
});

Deno.test("an unknown candidate kind is rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validRequestBody({ candidates: validCandidates({ images: [] }) }),
  );
});

Deno.test("a malformed candidate entry is dropped, not fatal", () => {
  // Candidates are hints from on-device regexes. One odd match must not cost
  // the user their whole analysis.
  const parsed = parseAnalyzeRequest(
    validRequestBody({
      candidates: validCandidates({
        times: [
          { raw_text: "9:30", hour: 9, minute: 30, is_ambiguous: false },
          { raw_text: "25:00", hour: 25, minute: 0, is_ambiguous: false },
          { raw_text: "", hour: 1, minute: 0, is_ambiguous: false },
          "not an object",
        ],
      }),
    }),
    CONFIG,
  );

  assertEquals(parsed.candidates.times.length, 1);
  assertEquals(parsed.droppedCandidates, 3);
});

Deno.test("unknown fields inside a candidate never reach the prompt", () => {
  const parsed = parseAnalyzeRequest(
    validRequestBody({
      candidates: validCandidates({
        phones: [
          {
            raw_text: "0100-123-4567",
            normalized_number: "01001234567",
            is_ambiguous: false,
            gps: "30.04,31.23",
          },
        ],
      }),
    }),
    CONFIG,
  );

  assertEquals(Object.keys(parsed.candidates.phones[0]).sort(), [
    "is_ambiguous",
    "normalized_number",
    "raw_text",
  ]);
});

Deno.test("candidate arrays are capped per kind", () => {
  // Unbounded candidates would blow the prompt, which is billed per token and
  // reserved against a per-minute quota.
  const many = Array.from({ length: 250 }, (_, index) => ({
    raw_text: `مرجع ${index}`,
    value: String(index),
    is_ambiguous: true,
  }));

  const parsed = parseAnalyzeRequest(
    validRequestBody({ candidates: validCandidates({ references: many }) }),
    CONFIG,
  );

  assertEquals(parsed.candidates.references.length, 100);
  assertEquals(parsed.droppedCandidates, 150);
});

Deno.test("an absent optional candidate field reads as null", () => {
  const parsed = parseAnalyzeRequest(
    validRequestBody({
      candidates: validCandidates({
        amounts: [{ raw_text: "٨٥٠ جنيه", is_ambiguous: true }],
      }),
    }),
    CONFIG,
  );

  assertEquals(parsed.candidates.amounts[0].value, null);
  assertEquals(parsed.candidates.amounts[0].currency, null);
  assertEquals(parsed.droppedCandidates, 0);
});

// ── image-intake path (§29b, F13-T09) ──────────────────────────────────────
// Not yet routed from analyze-handler.ts (F13-T11) — these test the contract
// in isolation, same as F13-T06's field-verification tests did ahead of T08.

function assertImageCode(code: string, body: unknown, config = CONFIG): void {
  const error = assertThrows(
    () => parseAnalyzeImageRequest(body, config),
    ApiError,
  ) as ApiError;
  assertEquals(error.code, code);
}

Deno.test("a valid image body parses into the typed request", () => {
  const parsed = parseAnalyzeImageRequest(validImageRequestBody(), CONFIG);

  assertEquals(parsed.inputType, "image");
  assertEquals(parsed.sessionId, SESSION_ID);
  assertEquals(parsed.installationId, INSTALLATION_ID);
  assertEquals(parsed.image.mimeType, "image/jpeg");
  assertEquals(parsed.image.data instanceof Uint8Array, true);
  assertEquals(parsed.image.data.length > 0, true);
});

Deno.test("image/png is accepted alongside image/jpeg", () => {
  const parsed = parseAnalyzeImageRequest(
    validImageRequestBody({ image: { data: VALID_IMAGE_BASE64, mime_type: "image/png" } }),
    CONFIG,
  );
  assertEquals(parsed.image.mimeType, "image/png");
});

Deno.test('input_type must be exactly "image" on the image shape', () => {
  assertImageCode("INVALID_REQUEST", validImageRequestBody({ input_type: "text" }));
});

Deno.test("a text-shaped field on the image body is rejected outright", () => {
  // Each shape has its own closed allow-list — an image body can never
  // smuggle ocr_text/candidates alongside the image.
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody({ ocr_text: "hello" }),
  );
});

Deno.test("an unsupported mime type is rejected", () => {
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody({ image: { data: VALID_IMAGE_BASE64, mime_type: "image/gif" } }),
  );
});

Deno.test("an unknown key inside image is rejected", () => {
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody({
      image: { data: VALID_IMAGE_BASE64, mime_type: "image/jpeg", gps: "30.0,31.2" },
    }),
  );
});

Deno.test("malformed base64 is rejected", () => {
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody({ image: { data: "not-base64!!", mime_type: "image/jpeg" } }),
  );
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody({ image: { data: "", mime_type: "image/jpeg" } }),
  );
});

Deno.test("a decoded image over maxImageBytes is rejected", () => {
  const config = testConfig({ maxImageBytes: 100 });
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody(),
    config,
  );
});

Deno.test("session and installation ids must be uuids on the image shape too", () => {
  assertImageCode(
    "INVALID_REQUEST",
    validImageRequestBody({ session_id: "not-a-uuid" }),
  );
});
