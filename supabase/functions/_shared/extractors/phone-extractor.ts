/**
 * F13-T05 · Phone candidate extraction (Azure text path).
 *
 * TypeScript port of `lib/features/ocr/domain/services/phone_extractor.dart`,
 * field-for-field.
 *
 * Supports:
 * - Mobile: 11 digits starting with 010/011/012/015.
 * - International: +20 or 002 prefix followed by 10 digits.
 * - Whitespace tolerance: strips spaces, dashes, dots between digits before
 *   validating (OCR frequently fragments long numbers).
 */

import type { PhoneCandidate } from "../prompts/analysis-prompt.ts";

// Matches digit sequences of 10-15 chars (after stripping separators),
// optionally preceded by + or 00. Allows spaces/dashes/dots between digit
// groups.
const PHONE_PATTERN = /(?:\+|00)?(?:\d[\s\-.]*){10,15}/g;

const VALID_MOBILE_PREFIXES = new Set(["010", "011", "012", "015"]);

export function extractPhones(text: string): PhoneCandidate[] {
  const candidates: PhoneCandidate[] = [];
  const seen = new Set<string>();

  for (const match of text.matchAll(PHONE_PATTERN)) {
    const candidate = parse(match[0]);
    if (candidate !== null && !seen.has(candidate.normalized_number)) {
      seen.add(candidate.normalized_number);
      candidates.push(candidate);
    }
  }

  return candidates;
}

function parse(raw: string): PhoneCandidate | null {
  const digitsOnly = raw.replace(/[^\d]/g, "");
  const trimmed = raw.trim();
  const hasWhitespace = /\s/.test(trimmed);

  // International format: +20xxxxxxxxxx or 002xxxxxxxxxx
  if (digitsOnly.startsWith("20") && digitsOnly.length === 12) {
    const local = `0${digitsOnly.substring(2)}`;
    if (isValidEgyptianMobile(local)) {
      return { raw_text: trimmed, normalized_number: local, is_ambiguous: hasWhitespace };
    }
  }
  if (digitsOnly.startsWith("002") && digitsOnly.length === 14) {
    const local = `0${digitsOnly.substring(4)}`;
    if (isValidEgyptianMobile(local)) {
      return { raw_text: trimmed, normalized_number: local, is_ambiguous: hasWhitespace };
    }
  }

  // Local format: 0xxxxxxxxxx (11 digits)
  if (digitsOnly.length === 11 && isValidEgyptianMobile(digitsOnly)) {
    return { raw_text: trimmed, normalized_number: digitsOnly, is_ambiguous: hasWhitespace };
  }

  return null;
}

function isValidEgyptianMobile(digits: string): boolean {
  if (digits.length !== 11) return false;
  return VALID_MOBILE_PREFIXES.has(digits.substring(0, 3));
}
