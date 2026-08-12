/**
 * F13-T03 · Tests for Google Document AI env-var reading.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { googleDocumentAiOptionsFromEnv } from "../../functions/_shared/google/google-config.ts";

/** Stands in for Deno.env so tests never touch the real environment. */
function env(values: Record<string, string> = {}) {
  return { get: (key: string) => values[key] };
}

const COMPLETE = {
  GOOGLE_DOCUMENT_AI_CLIENT_EMAIL: "svc@project.iam.gserviceaccount.com",
  GOOGLE_DOCUMENT_AI_PRIVATE_KEY:
    "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n",
  GOOGLE_DOCUMENT_AI_PROJECT_ID: "war2aty-prod",
  GOOGLE_DOCUMENT_AI_LOCATION: "eu",
  GOOGLE_DOCUMENT_AI_PROCESSOR_ID: "abc123",
};

Deno.test("reads all five values from the environment", () => {
  const options = googleDocumentAiOptionsFromEnv(env(COMPLETE));

  assertEquals(options.clientEmail, "svc@project.iam.gserviceaccount.com");
  assertEquals(options.projectId, "war2aty-prod");
  assertEquals(options.location, "eu");
  assertEquals(options.processorId, "abc123");
});

Deno.test("unescapes literal \\n sequences in the private key into real newlines", () => {
  const options = googleDocumentAiOptionsFromEnv(env(COMPLETE));

  assertEquals(
    options.privateKey,
    "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n",
  );
});

Deno.test("each required var hard-fails on its own when missing", () => {
  for (const key of Object.keys(COMPLETE)) {
    const partial = { ...COMPLETE };
    delete (partial as Record<string, string>)[key];

    assertThrows(
      () => googleDocumentAiOptionsFromEnv(env(partial)),
      Error,
      key,
      `missing ${key} should hard-fail`,
    );
  }
});

Deno.test("a blank value is treated the same as a missing one", () => {
  assertThrows(
    () =>
      googleDocumentAiOptionsFromEnv(env({
        ...COMPLETE,
        GOOGLE_DOCUMENT_AI_PROCESSOR_ID: "   ",
      })),
    Error,
    "GOOGLE_DOCUMENT_AI_PROCESSOR_ID",
  );
});

Deno.test("everything missing hard-fails on the first required var", () => {
  assertThrows(
    () => googleDocumentAiOptionsFromEnv(env()),
    Error,
    "GOOGLE_DOCUMENT_AI_CLIENT_EMAIL",
  );
});
