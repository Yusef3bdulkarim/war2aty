/**
 * F13-T05 · Amount candidate extraction (Azure text path).
 *
 * TypeScript port of `lib/features/ocr/domain/services/amount_extractor.dart`,
 * field-for-field.
 *
 * Two strategies:
 * 1. **Explicit currency** — a number adjacent to a recognized currency
 *    marker (EGP, LE, $, €, USD, EUR). Not ambiguous.
 * 2. **Keyword-adjacent** — a number near Arabic money keywords
 *    (إجمالي, المطلوب, القيمة, مبلغ, سعر, رسوم, ضريبة, خصم). Flagged ambiguous.
 */

import type { AmountCandidate } from "../prompts/analysis-prompt.ts";

export function extractAmounts(text: string): AmountCandidate[] {
  const candidates: AmountCandidate[] = [];
  const usedRanges: Array<[number, number]> = [];

  for (const match of text.matchAll(EXPLICIT_CURRENCY_PATTERN)) {
    const candidate = parseExplicit(match);
    if (candidate !== null) {
      candidates.push(candidate);
      usedRanges.push([match.index!, match.index! + match[0].length]);
    }
  }

  for (const match of text.matchAll(KEYWORD_PATTERN)) {
    if (overlaps(match, usedRanges)) continue;
    const candidate = parseKeywordAdjacent(match);
    if (candidate !== null) candidates.push(candidate);
  }

  return candidates;
}

// ── Explicit currency: number + currency marker (or marker + number) ──────

const EXPLICIT_CURRENCY_PATTERN =
  /(\d[\d,]*\.?\d*)\s*(EGP|LE|USD|\$|EUR|€)|(EGP|LE|USD|\$|EUR|€)\s*(\d[\d,]*\.?\d*)/g;

function parseExplicit(match: RegExpMatchArray): AmountCandidate | null {
  const raw = match[0];
  const numberStr = match[1] ?? match[4];
  const currencyStr = match[2] ?? match[3];

  if (numberStr === undefined || currencyStr === undefined) return null;
  const value = parseNumber(numberStr);
  if (value === null) return null;

  const currency = normalizeCurrency(currencyStr);
  return { raw_text: raw, value, currency, is_ambiguous: false };
}

// ── Keyword-adjacent: Arabic money keyword near a number ──────────────────

/** Exported for T06 field verification — used to group amounts under a shared label. */
export const AMOUNT_KEYWORDS = [
  "إجمالي",
  "اجمالي",
  "المطلوب",
  "القيمة",
  "المبلغ",
  "مبلغ",
  "سعر",
  "رسوم",
  "ضريبة",
  "خصم",
  "صافي",
  "المستحق",
  "قيمة",
  "تكلفة",
  "ثمن",
];

const KEYWORD_PATTERN = new RegExp(
  `(?:${AMOUNT_KEYWORDS.join("|")})[\\s:]*(\\d[\\d,]*\\.?\\d*)`,
  "g",
);

function parseKeywordAdjacent(match: RegExpMatchArray): AmountCandidate | null {
  const raw = match[0];
  const numberStr = match[1];
  if (numberStr === undefined) return null;

  const value = parseNumber(numberStr);
  if (value === null) return null;

  return { raw_text: raw, value, currency: null, is_ambiguous: true };
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function parseNumber(raw: string): number | null {
  const cleaned = raw.replaceAll(",", "");
  const value = Number(cleaned);
  return Number.isFinite(value) ? value : null;
}

function normalizeCurrency(raw: string): string {
  switch (raw) {
    case "LE":
    case "EGP":
      return "EGP";
    case "$":
    case "USD":
      return "USD";
    case "€":
    case "EUR":
      return "EUR";
    default:
      return raw;
  }
}

function overlaps(match: RegExpMatchArray, ranges: ReadonlyArray<[number, number]>): boolean {
  const start = match.index!;
  const end = start + match[0].length;
  for (const [rangeStart, rangeEnd] of ranges) {
    if (start < rangeEnd && end > rangeStart) return true;
  }
  return false;
}
