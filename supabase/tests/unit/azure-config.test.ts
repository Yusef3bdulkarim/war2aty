/**
 * F13-T03 · Tests for Azure Document Intelligence env-var reading.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { azureOptionsFromEnv } from "../../functions/_shared/azure/azure-config.ts";

/** Stands in for Deno.env so tests never touch the real environment. */
function env(values: Record<string, string> = {}) {
  return { get: (key: string) => values[key] };
}

Deno.test("reads endpoint and key from the environment", () => {
  const options = azureOptionsFromEnv(env({
    AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: "https://example.cognitiveservices.azure.com",
    AZURE_DOCUMENT_INTELLIGENCE_KEY: "test-key",
  }));

  assertEquals(options.endpoint, "https://example.cognitiveservices.azure.com");
  assertEquals(options.key, "test-key");
});

Deno.test("a missing endpoint hard-fails rather than silently degrading", () => {
  assertThrows(
    () => azureOptionsFromEnv(env({ AZURE_DOCUMENT_INTELLIGENCE_KEY: "test-key" })),
    Error,
    "AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT",
  );
});

Deno.test("a missing key hard-fails rather than silently degrading", () => {
  assertThrows(
    () =>
      azureOptionsFromEnv(env({
        AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: "https://example.cognitiveservices.azure.com",
      })),
    Error,
    "AZURE_DOCUMENT_INTELLIGENCE_KEY",
  );
});

Deno.test("a blank value is treated the same as a missing one", () => {
  assertThrows(
    () =>
      azureOptionsFromEnv(env({
        AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: "   ",
        AZURE_DOCUMENT_INTELLIGENCE_KEY: "test-key",
      })),
    Error,
    "AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT",
  );
});

Deno.test("both vars missing reports the endpoint first", () => {
  assertThrows(
    () => azureOptionsFromEnv(env()),
    Error,
    "AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT",
  );
});
