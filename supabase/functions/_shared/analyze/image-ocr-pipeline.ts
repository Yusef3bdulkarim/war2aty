/**
 * F20-T13 · The online OCR pipeline: image in, text and candidates out.
 *
 * Gemini reads the page, the digits are folded, and the T05 extractors turn
 * the reading into candidates. That is the whole pipeline. Gemini returns no
 * per-word confidences, so the Azure-era verification layer has nothing to
 * work with here (F20 context §1).
 *
 * ── Why the digits are folded first (F17 `8576134`) ───────────────────────
 * Every extractor matches `\d`, which in JavaScript is `[0-9]` and never
 * `٠-٩`. Egyptian bills, receipts and government forms write their dates,
 * amounts and phone numbers in Arabic-Indic numerals, so without the fold the
 * candidate set comes back empty on exactly the documents the app exists to
 * read. The folded text is also what is handed onward as `ocrText`, matching
 * the offline path, where the app's `TextNormalizer` folds before sending.
 *
 * Failures are the client's `ProviderFailure`, unchanged. Turning one into a
 * §31 error is the handler's job (`ocrApiErrorFor`), because the same failure
 * means different things to different endpoints.
 *
 * PRIVACY (§7, §51): nothing here logs. The image, the reading and the
 * candidates pass through without being recorded.
 */

import type { GeminiOcrClient } from "../ai/gemini-ocr-client.ts";
import { runExtractors } from "../extractors/run-extractors.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import { normaliseDigits } from "../validators/text-matching.ts";

export interface ImageOcrInput {
  readonly data: Uint8Array;
  readonly mimeType: string;
}

export interface ImageOcrResult {
  /** The reading with both Arabic-Indic digit systems folded to ASCII. */
  readonly ocrText: string;
  readonly candidates: ExtractedCandidates;
}

/** Throws the reader's `ProviderFailure` when there is no reading. */
export type ImageOcrPipeline = (
  input: ImageOcrInput,
  signal: AbortSignal,
) => Promise<ImageOcrResult>;

export interface ImageOcrPipelineOptions {
  readonly geminiClient: GeminiOcrClient;
}

/**
 * Everything the pipeline does after the read: fold, then extract.
 *
 * Exported so the benchmark scores exactly this step on any reading, Gemini's
 * or Tesseract's, rather than a copy of it. F17 learned that a benchmark
 * reimplementing the pipeline misses fixes made inside it.
 */
export function readingFromText(text: string): ImageOcrResult {
  const ocrText = normaliseDigits(text);
  return { ocrText, candidates: runExtractors(ocrText) };
}

export function createImageOcrPipeline(options: ImageOcrPipelineOptions): ImageOcrPipeline {
  const { geminiClient } = options;

  return async (input, signal) => {
    const { text } = await geminiClient({ bytes: input.data, mimeType: input.mimeType }, signal);
    return readingFromText(text);
  };
}
