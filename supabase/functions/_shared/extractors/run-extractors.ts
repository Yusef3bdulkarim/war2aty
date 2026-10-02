/**
 * Every T05 extractor over one OCR reading, in `ExtractedCandidates`' own field
 * order.
 *
 * Used by the online OCR pipeline (F20-T13; it was shared with the Azure
 * image-analysis pipeline until F20-T15 deleted that). The extractors match
 * `\d`, which never matches `٠-٩`: callers fold digits first
 * (`normaliseDigits`).
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
