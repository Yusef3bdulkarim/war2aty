/**
 * F36-T14 · Tests for the explain-document request parser (§33).
 *
 * One test per rejection path, plus a happy-path that exercises the full
 * decode. The structure mirrors `analyze-request.test.ts`.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { parseExplainRequest } from "../../functions/_shared/explain/explain-request.ts";
import {
  INSTALLATION_ID,
  SESSION_ID,
  testConfig,
  VALID_IMAGE_BASE64,
  validExplainBody,
} from "../fixtures/explain-fixtures.ts";

const CONFIG = testConfig();

function assertCode(code: string, body: unknown, config = CONFIG): void {
  const error = assertThrows(
    () => parseExplainRequest(body, config),
    ApiError,
  ) as ApiError;
  assertEquals(error.code, code);
}

// ── happy path ───────────────────────────────────────────────────────────

Deno.test("a valid body parses into the typed request", () => {
  const parsed = parseExplainRequest(validExplainBody(), CONFIG);

  assertEquals(parsed.sessionId, SESSION_ID.toLowerCase());
  assertEquals(parsed.installationId, INSTALLATION_ID.toLowerCase());
  assertEquals(parsed.appVersion, "1.0.0");
  assertEquals(parsed.image.mimeType, "image/jpeg");
  assertEquals(parsed.image.data instanceof Uint8Array, true);
  assertEquals(parsed.image.data.length > 0, true);
});

Deno.test("UUIDs with uppercase letters are lowercased", () => {
  const parsed = parseExplainRequest(
    validExplainBody({
      session_id: "3F2504E0-4F89-41D3-9A0C-0305E82C3301",
      installation_id: "9C858901-8A57-4791-81FE-4C455B099BC9",
    }),
    CONFIG,
  );
  assertEquals(parsed.sessionId, "3f2504e0-4f89-41d3-9a0c-0305e82c3301");
  assertEquals(parsed.installationId, "9c858901-8a57-4791-81fe-4c455b099bc9");
});

// ── envelope ─────────────────────────────────────────────────────────────

Deno.test("a non-object body is rejected", () => {
  assertCode("INVALID_REQUEST", null);
  assertCode("INVALID_REQUEST", "hello");
  assertCode("INVALID_REQUEST", 42);
  assertCode("INVALID_REQUEST", []);
});

Deno.test("an extra top-level key is rejected", () => {
  assertCode("INVALID_REQUEST", validExplainBody({ extra: true }));
});

Deno.test("an analyze-shaped body (carries schema_version and input_type) is rejected", () => {
  // This is the §33 contract separation test: a body that would pass the
  // analyze parser fails here because `schema_version` and `input_type` are
  // not in the closed allow-list.
  assertCode("INVALID_REQUEST", {
    schema_version: "2.0",
    session_id: SESSION_ID,
    installation_id: INSTALLATION_ID,
    app_version: "1.0.0",
    input_type: "image",
    image: { data: VALID_IMAGE_BASE64, mime_type: "image/jpeg" },
  });
});

// ── schema version ───────────────────────────────────────────────────────

Deno.test("a missing explain_schema_version is rejected", () => {
  const body = validExplainBody();
  delete body.explain_schema_version;
  assertCode("INVALID_REQUEST", body);
});

Deno.test("a non-string explain_schema_version is rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({ explain_schema_version: 1.0 }),
  );
});

Deno.test('version "2.0" is refused as unsupported', () => {
  assertCode(
    "UNSUPPORTED_SCHEMA",
    validExplainBody({ explain_schema_version: "2.0" }),
  );
});

Deno.test('version "1.00" is refused as unsupported (strict string equality)', () => {
  assertCode(
    "UNSUPPORTED_SCHEMA",
    validExplainBody({ explain_schema_version: "1.00" }),
  );
});

// ── app version ──────────────────────────────────────────────────────────

Deno.test("a missing app_version is rejected", () => {
  const body = validExplainBody();
  delete body.app_version;
  assertCode("INVALID_REQUEST", body);
});

Deno.test("an app_version that does not match semver is rejected", () => {
  assertCode("INVALID_REQUEST", validExplainBody({ app_version: "abc" }));
  assertCode("INVALID_REQUEST", validExplainBody({ app_version: "1.0" }));
});

Deno.test("an app version below the minimum is refused", () => {
  assertCode(
    "UNSUPPORTED_APP_VERSION",
    validExplainBody({ app_version: "0.9.0" }),
    testConfig({ minimumAppVersion: "1.0.0" }),
  );
});

// ── session_id / installation_id ─────────────────────────────────────────

Deno.test("a missing session_id is rejected", () => {
  const body = validExplainBody();
  delete body.session_id;
  assertCode("INVALID_REQUEST", body);
});

Deno.test("a non-UUID session_id is rejected", () => {
  assertCode("INVALID_REQUEST", validExplainBody({ session_id: "not-a-uuid" }));
});

Deno.test("a missing installation_id is rejected", () => {
  const body = validExplainBody();
  delete body.installation_id;
  assertCode("INVALID_REQUEST", body);
});

Deno.test("a non-UUID installation_id is rejected", () => {
  assertCode("INVALID_REQUEST", validExplainBody({ installation_id: 12345 }));
});

// ── image ────────────────────────────────────────────────────────────────

Deno.test("a missing image is rejected", () => {
  const body = validExplainBody();
  delete body.image;
  assertCode("INVALID_REQUEST", body);
});

Deno.test("an image that is not an object is rejected", () => {
  assertCode("INVALID_REQUEST", validExplainBody({ image: "not-an-object" }));
});

Deno.test("an image with an extra key is rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({
      image: { data: VALID_IMAGE_BASE64, mime_type: "image/jpeg", width: 100 },
    }),
  );
});

Deno.test("an unsupported mime type is rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({
      image: { data: VALID_IMAGE_BASE64, mime_type: "image/webp" },
    }),
  );
});

Deno.test("a non-string image.data is rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({
      image: { data: 42, mime_type: "image/jpeg" },
    }),
  );
});

Deno.test("an empty base64 string is rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({
      image: { data: "", mime_type: "image/jpeg" },
    }),
  );
});

Deno.test("invalid base64 characters are rejected", () => {
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({
      image: { data: "not!valid!base64", mime_type: "image/jpeg" },
    }),
  );
});

Deno.test("an oversize image is rejected", () => {
  // 16 decoded bytes = 24 base64 characters; maxImageBytes = 8 rejects it.
  const tinyConfig = testConfig({ maxImageBytes: 8 });
  const smallBase64 = btoa("A".repeat(16));
  assertCode(
    "INVALID_REQUEST",
    validExplainBody({
      image: { data: smallBase64, mime_type: "image/jpeg" },
    }),
    tinyConfig,
  );
});

Deno.test("a PNG image is accepted", () => {
  // Use the same payload — the parser does not verify the magic bytes, only the
  // mime type. A real PNG's magic bytes would differ, but the contract check
  // is on the declared type, not the byte content.
  const parsed = parseExplainRequest(
    validExplainBody({
      image: { data: VALID_IMAGE_BASE64, mime_type: "image/png" },
    }),
    CONFIG,
  );
  assertEquals(parsed.image.mimeType, "image/png");
});
