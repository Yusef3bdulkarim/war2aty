/**
 * F20-T13 · Tests for the online OCR pipeline: Gemini, fold, extract.
 *
 * The Gemini client is a fake, so these pin what the pipeline does with a
 * reading, never what Gemini reads.
 */

import { assertEquals, assertRejects, assertStrictEquals } from "jsr:@std/assert@1";

import {
  createImageOcrPipeline,
  readingFromText,
} from "../../functions/_shared/analyze/image-ocr-pipeline.ts";
import type { GeminiOcrClient, OcrImage } from "../../functions/_shared/ai/gemini-ocr-client.ts";
import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";

const IMAGE = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
const MIME_TYPE = "image/jpeg";

/** A Gemini client that returns `text` and records what it was asked. */
function reading(text: string) {
  const calls: { image: OcrImage; signal: AbortSignal }[] = [];
  const client: GeminiOcrClient = (image, signal) => {
    calls.push({ image, signal });
    return Promise.resolve({ text });
  };
  return { client, calls };
}

async function read(text: string) {
  const pipeline = createImageOcrPipeline({ geminiClient: reading(text).client });
  return await pipeline({ data: IMAGE, mimeType: MIME_TYPE }, new AbortController().signal);
}

// ── the call ──────────────────────────────────────────────────────────────

Deno.test("the image and the caller's signal reach Gemini unchanged", async () => {
  const { client, calls } = reading("نص");
  const signal = new AbortController().signal;

  await createImageOcrPipeline({ geminiClient: client })(
    { data: IMAGE, mimeType: MIME_TYPE },
    signal,
  );

  assertEquals(calls.length, 1);
  assertStrictEquals(calls[0].image.bytes, IMAGE);
  assertEquals(calls[0].image.mimeType, MIME_TYPE);
  assertStrictEquals(calls[0].signal, signal);
});

Deno.test("a reader failure propagates unchanged, for the handler to map", async () => {
  const failure = new ProviderFailure("upstream_unavailable");
  const pipeline = createImageOcrPipeline({ geminiClient: () => Promise.reject(failure) });

  const thrown = await assertRejects(() =>
    pipeline({ data: IMAGE, mimeType: MIME_TYPE }, new AbortController().signal)
  );

  assertStrictEquals(thrown, failure);
});

// ── the reading ───────────────────────────────────────────────────────────

Deno.test("an empty reading is an empty text with no candidates (O2)", async () => {
  const result = await read("");

  assertEquals(result.ocrText, "");
  assertEquals(result.candidates, {
    dates: [],
    times: [],
    amounts: [],
    phones: [],
    references: [],
  });
});

Deno.test("an ASCII reading passes through as it is", async () => {
  const result = await read("Total 850.50 EGP");

  assertEquals(result.ocrText, "Total 850.50 EGP");
  assertEquals(result.candidates.amounts[0].value, 850.5);
});

// ── F17 `8576134` · Arabic-Indic digits, ported ───────────────────────────
//
// Every extractor matches on `\d`, which is `[0-9]` in JavaScript and never
// `٠-٩`. Egyptian bills, receipts and government forms write their dates,
// amounts and phone numbers in Arabic-Indic numerals, so without the fold the
// entire candidate set came back empty on exactly the documents the app exists
// to read. F17's third test (word offsets staying valid) has no counterpart:
// Gemini returns no word offsets.

Deno.test("Arabic-Indic dates reach the extractors", async () => {
  const result = await read("فاتورة الكهرباء\nتاريخ الاستحقاق ٢٢/٤/٢٠٢٥");

  assertEquals(result.candidates.dates.length, 1);
  assertEquals(result.candidates.dates[0].normalized_date, "2025-04-22");
});

Deno.test("Arabic-Indic amounts and phone numbers reach the extractors", async () => {
  const result = await read("المبلغ المستحق ١٢٥٠ جنيه\nللاستفسار ٠١٠٦٣٧٠٠٣٧٤");

  assertEquals(result.candidates.amounts.length, 1);
  assertEquals(result.candidates.amounts[0].value, 1250);
  assertEquals(result.candidates.phones.length, 1);
  assertEquals(result.candidates.phones[0].normalized_number, "01063700374");
});

Deno.test("ocrText handed onward is the folded text, matching the offline path", async () => {
  const result = await read("المبلغ ١٢٥٠ جنيه");

  assertEquals(result.ocrText, "المبلغ 1250 جنيه");
});

Deno.test("Extended (Persian) Arabic-Indic digits are folded too", async () => {
  const result = await read("المبلغ ۱۲۵۰ جنيه");

  assertEquals(result.ocrText, "المبلغ 1250 جنيه");
  assertEquals(result.candidates.amounts[0].value, 1250);
});

Deno.test("readingFromText is the pipeline's whole post-read step", async () => {
  // The benchmark scores this function; it must be exactly what ships.
  const text = "تاريخ الاستحقاق ٢٢/٤/٢٠٢٥ المبلغ ١٢٥٠ جنيه";

  assertEquals(readingFromText(text), await read(text));
});
