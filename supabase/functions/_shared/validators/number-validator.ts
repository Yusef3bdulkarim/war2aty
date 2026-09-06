/**
 * F06-T12 · Number verification (§34).
 *
 * Every amount, phone, invoice number, reference or ID the model reports must
 * exist in the OCR text or among the on-device candidates. If it does not, the
 * model produced it from nowhere, and a fabricated account number or amount is
 * exactly the harm this app must not cause.
 *
 * Unverified does NOT mean deleted. §34 asks for `not_verified` +
 * `needsUserReview`, which API_CONTRACT §30 expresses as `confidence: "low"` —
 * the client then shows «قراءة غير مؤكدة» and lets the user correct it. Removing
 * the value silently would be worse: the user would never learn the paper says
 * something we could not confirm.
 */

import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import { containsDigitSequence, containsNumber, digitsOf } from "./text-matching.ts";

export interface VerificationSources {
  readonly ocrText: string;
  readonly candidates: ExtractedCandidates;
}

/** Everything the candidates assert, flattened into one searchable string. */
function candidateText(candidates: ExtractedCandidates): string {
  return [
    ...candidates.amounts.map((c) => `${c.raw_text} ${c.value ?? ""}`),
    ...candidates.phones.map((c) => `${c.raw_text} ${c.normalized_number}`),
    ...candidates.references.map((c) => `${c.raw_text} ${c.value}`),
    ...candidates.dates.map((c) => `${c.raw_text} ${c.normalized_date ?? ""}`),
    ...candidates.times.map((c) => c.raw_text),
  ].join("\n");
}

/**
 * Whether a numeric value is present on the page.
 *
 * Checks the OCR text first, then the candidates: a rule-based extractor may
 * have normalised something the raw text spells differently.
 */
export function isNumberVerified(
  value: number,
  sources: VerificationSources,
): boolean {
  if (containsNumber(sources.ocrText, value)) return true;
  return containsNumber(candidateText(sources.candidates), value);
}

/**
 * Whether a reported identifier is present on the page.
 *
 * Digit-only comparison, so "0100-123-4567" printed matches "01001234567"
 * reported. A value with no digits at all (a name, a company) is not a number
 * and is left to the source validator.
 */
export function isIdentifierVerified(
  value: string,
  sources: VerificationSources,
): boolean {
  if (digitsOf(value).length === 0) return false;
  if (containsDigitSequence(sources.ocrText, value)) return true;
  return containsDigitSequence(candidateText(sources.candidates), value);
}

/**
 * True when a value looks like an identifier rather than prose.
 *
 * Only values that are mostly digits are subject to number verification;
 * "شركة جنوب القاهرة" is a name and is checked as text instead.
 */
export function looksNumeric(value: string): boolean {
  const digits = digitsOf(value).length;
  if (digits === 0) return false;
  const meaningful = value.replaceAll(/\s/g, "").length;
  return meaningful > 0 && digits / meaningful >= 0.5;
}
