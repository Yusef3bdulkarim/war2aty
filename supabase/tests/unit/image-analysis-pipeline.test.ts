/**
 * F13-T11 · Tests for the online image-analysis pipeline.
 *
 * Both provider clients are faked as plain functions — `AzureDocumentIntelligenceClient`
 * and `GoogleDocumentAiClient` are already the injection seams T04/T07 built for
 * exactly this, so no `fetch`, no network, no credentials.
 *
 * The questions here are sequencing ones: does Azure's text actually reach the
 * T05 extractors, does Google get called only when a critical field needs a
 * second opinion, does a failed Google call degrade to "unconfirmed" rather
 * than blowing up the whole analysis, and does a failed Azure call propagate
 * (locked decision #2 — a failed-while-online call must fail outright).
 */

import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import type { AzureDocumentIntelligenceClient } from "../../functions/_shared/azure/azure-client.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createImageAnalysisPipeline } from "../../functions/_shared/analyze/image-analysis-pipeline.ts";
import type { GoogleDocumentAiClient } from "../../functions/_shared/google/google-client.ts";

const IMAGE = new Uint8Array([1, 2, 3]);
const MIME_TYPE = "image/jpeg";

/** A word covering every occurrence of `text` in `content`, at the given confidence. */
function wordsIn(
  content: string,
  entries: Array<[text: string, confidence: number]>,
): { content: string; offset: number; length: number; confidence: number }[] {
  const words = [];
  let cursor = 0;
  for (const [text, confidence] of entries) {
    const offset = content.indexOf(text, cursor);
    if (offset === -1) {
      throw new Error(
        `fixture text not found in content after cursor ${cursor}: "${text}"`,
      );
    }
    words.push({ content: text, offset, length: text.length, confidence });
    cursor = offset + text.length;
  }
  return words;
}

Deno.test("with no candidates, Azure's text is extracted but Google is never consulted", async () => {
  let googleCalls = 0;
  const azureClient: AzureDocumentIntelligenceClient = () =>
    Promise.resolve({
      content: "nothing extractable here",
      modelId: "prebuilt-read",
      words: [],
    });
  const googleClient: GoogleDocumentAiClient = () => {
    googleCalls++;
    return Promise.reject(new Error("must not be called"));
  };

  const pipeline = createImageAnalysisPipeline({ azureClient, googleClient });
  const result = await pipeline({ data: IMAGE, mimeType: MIME_TYPE });

  assertEquals(result.ocrText, "nothing extractable here");
  assertEquals(result.candidates.dates, []);
  assertEquals(result.verification.needsUserReview, false);
  assertEquals(googleCalls, 0);
});

Deno.test("a low-confidence date triggers a Google second opinion, and agreement clears the review flag", async () => {
  const azureContent = "Due date 15/08/2026 amount 500 EGP total";
  // Both spans present, but scored low — the date will be `unverified`.
  const azureWords = wordsIn(azureContent, [
    ["15/08/2026", 0.4],
    ["500", 0.97],
    ["EGP", 0.97],
  ]);
  const azureClient: AzureDocumentIntelligenceClient = () =>
    Promise.resolve({
      content: azureContent,
      modelId: "prebuilt-read",
      words: azureWords,
    });

  let googleCalls = 0;
  const googleClient: GoogleDocumentAiClient = () => {
    googleCalls++;
    // Google's own resend, independently re-read, agrees on the same date.
    return Promise.resolve({ content: "15/08/2026 mentioned again here" });
  };

  const pipeline = createImageAnalysisPipeline({ azureClient, googleClient });
  const result = await pipeline({ data: IMAGE, mimeType: MIME_TYPE });

  assertEquals(googleCalls, 1);
  assertEquals(result.candidates.dates.length, 1);
  assertEquals(result.verification.dates[0].needsUserReview, false);
  assertEquals(result.verification.needsUserReview, false);
});

Deno.test("Google's failure is swallowed — the field stays flagged, the analysis still returns", async () => {
  const azureContent = "Due date 15/08/2026 amount 500 EGP total";
  const azureWords = wordsIn(azureContent, [
    ["15/08/2026", 0.4],
    ["500", 0.97],
    ["EGP", 0.97],
  ]);
  const azureClient: AzureDocumentIntelligenceClient = () =>
    Promise.resolve({
      content: azureContent,
      modelId: "prebuilt-read",
      words: azureWords,
    });

  const googleClient: GoogleDocumentAiClient = () => Promise.reject(ApiError.timeout());

  const pipeline = createImageAnalysisPipeline({ azureClient, googleClient });
  const result = await pipeline({ data: IMAGE, mimeType: MIME_TYPE });

  assertEquals(result.candidates.dates.length, 1);
  assertEquals(result.verification.dates[0].needsUserReview, true);
  assertEquals(result.verification.needsUserReview, true);
});

Deno.test("an Azure failure propagates and Google is never called", async () => {
  const azureClient: AzureDocumentIntelligenceClient = () => Promise.reject(ApiError.timeout());
  let googleCalls = 0;
  const googleClient: GoogleDocumentAiClient = () => {
    googleCalls++;
    return Promise.reject(new Error("must not be called"));
  };

  const pipeline = createImageAnalysisPipeline({ azureClient, googleClient });

  await assertRejects(
    () => pipeline({ data: IMAGE, mimeType: MIME_TYPE }),
    ApiError,
  );
  assertEquals(googleCalls, 0);
});
