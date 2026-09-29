/**
 * Every T05 extractor over one OCR reading, in `ExtractedCandidates`' own field
 * order.
 *
 * Shared by the online OCR pipeline (F20-T13) and, until F20-T15 deletes it,
 * the Azure image-analysis pipeline. The extractors match `\d`, which never
 * matches `٠-٩`: callers fold digits first (`normaliseDigits`).
 */

import { extractAmounts } from "./amount-extractor.ts";
import { extractDates } from "./date-extractor.ts";
import { extractPhones } from "./phone-extractor.ts";
import { extractReferences } from "./reference-extractor.ts";
import { extractTimes } from "./time-extractor.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";

export function runExtractors(text: string): ExtractedCandidates {
  return {
    dates: extractDates(text),
    times: extractTimes(text),
    amounts: extractAmounts(text),
    phones: extractPhones(text),
    references: extractReferences(text),
  };
}
