/**
 * F13-T05 · Reference/account/invoice number extraction (Azure text path).
 *
 * TypeScript port of
 * `lib/features/ocr/domain/services/reference_extractor.dart`, field-for-field.
 *
 * Strategy: find Arabic keywords (رقم الحساب, رقم الفاتورة, etc.) followed by
 * an alphanumeric sequence of 4+ characters. All candidates are flagged
 * ambiguous — reference formats vary too widely to validate.
 */

import type { ReferenceCandidate } from "../prompts/analysis-prompt.ts";

/** Exported for T06 field verification — used to group references under a shared label. */
export const REFERENCE_KEYWORDS = [
  "رقم الحساب",
  "رقم حساب",
  "رقم الفاتورة",
  "رقم فاتورة",
  "رقم مرجعي",
  "رقم المرجع",
  "رقم الإيصال",
  "رقم الايصال",
  "رقم إيصال",
  "رقم ايصال",
  "رقم الحجز",
  "رقم حجز",
  "رقم العملية",
  "رقم عملية",
  "رقم المعاملة",
  "كود",
  "Ref",
  "REF",
  "Invoice",
  "Account",
  "Booking",
  "Transaction",
];

const REFERENCE_PATTERN = new RegExp(
  `(?:${REFERENCE_KEYWORDS.join("|")})[\\s:#]*([A-Za-z0-9][\\w\\-/]*[A-Za-z0-9]|\\d{4,})`,
  "gi",
);

export function extractReferences(text: string): ReferenceCandidate[] {
  const candidates: ReferenceCandidate[] = [];
  const seen = new Set<string>();

  for (const match of text.matchAll(REFERENCE_PATTERN)) {
    const value = match[1]?.trim();
    if (value === undefined || value.length < 4) continue;
    if (seen.has(value)) continue;
    seen.add(value);

    candidates.push({ raw_text: match[0], value, is_ambiguous: true });
  }

  return candidates;
}
