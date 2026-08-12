/**
 * F13-T05 · Date candidate extraction (Azure text path).
 *
 * TypeScript port of `lib/features/ocr/domain/services/date_extractor.dart`,
 * field-for-field. Runs server-side over Azure's `content` string instead of
 * on-device, so an online analysis gets the same candidate hints an offline
 * one gets from the Dart extractor — the model-facing shape (§ prompts) does
 * not need to know which pipeline produced them.
 *
 * Supports:
 * - Numeric formats: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY (optional 2-digit
 *   year). Day-first per Egyptian convention.
 * - Arabic month names: يناير..ديسمبر (full and common abbreviations).
 * - English month names: January..December, Jan..Dec.
 * - Hijri month names: محرم..ذو الحجة — detected with normalized_date=null
 *   and is_ambiguous=true.
 *
 * `normalized_date` is an ISO-8601 `YYYY-MM-DD` string, not a `Date` object —
 * this is the wire shape `DateCandidate` already uses (see
 * `../prompts/analysis-prompt.ts` and `../validators/date-validator.ts`).
 */

import type { DateCandidate } from "../prompts/analysis-prompt.ts";

export function extractDates(text: string): DateCandidate[] {
  const candidates: DateCandidate[] = [];

  for (const match of text.matchAll(NUMERIC_DATE_PATTERN)) {
    const candidate = parseNumericDate(match);
    if (candidate !== null) candidates.push(candidate);
  }

  for (const match of text.matchAll(ARABIC_MONTH_DATE_PATTERN)) {
    const candidate = parseArabicMonthDate(match);
    if (candidate !== null) candidates.push(candidate);
  }

  for (const match of text.matchAll(ENGLISH_MONTH_DATE_PATTERN)) {
    const candidate = parseEnglishMonthDate(match);
    if (candidate !== null) candidates.push(candidate);
  }

  for (const match of text.matchAll(HIJRI_PATTERN)) {
    candidates.push({ raw_text: match[0], normalized_date: null, is_ambiguous: true });
  }

  return candidates;
}

// ── Numeric dates: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY ─────────────────────

const NUMERIC_DATE_PATTERN = /(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{2,4})/g;

function parseNumericDate(match: RegExpMatchArray): DateCandidate | null {
  const raw = match[0];
  const day = Number(match[1]);
  const month = Number(match[2]);
  let year = Number(match[3]);

  if (year < 100) year += 2000;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;

  const isAmbiguous = day <= 12 && month <= 12 && day !== month;

  const normalizedDate = toIsoDate(year, month, day);
  if (normalizedDate === null) return null;

  return { raw_text: raw, normalized_date: normalizedDate, is_ambiguous: isAmbiguous };
}

// ── Arabic Gregorian month names ───────────────────────────────────────────

const ARABIC_MONTHS: ReadonlyMap<string, number> = new Map([
  ["يناير", 1],
  ["فبراير", 2],
  ["مارس", 3],
  ["أبريل", 4],
  ["إبريل", 4],
  ["ابريل", 4],
  ["مايو", 5],
  ["يونيو", 6],
  ["يونيه", 6],
  ["يوليو", 7],
  ["يوليه", 7],
  ["أغسطس", 8],
  ["اغسطس", 8],
  ["سبتمبر", 9],
  ["أكتوبر", 10],
  ["اكتوبر", 10],
  ["نوفمبر", 11],
  ["ديسمبر", 12],
]);

const ARABIC_MONTH_NAMES = Array.from(ARABIC_MONTHS.keys()).join("|");

const ARABIC_MONTH_DATE_PATTERN = new RegExp(
  `(\\d{1,2})\\s*(?:من\\s+)?(${ARABIC_MONTH_NAMES})\\s*(\\d{2,4})?`,
  "g",
);

function parseArabicMonthDate(match: RegExpMatchArray): DateCandidate | null {
  const raw = match[0];
  const day = Number(match[1]);
  const monthName = match[2];
  const yearStr = match[3] as string | undefined;

  if (day < 1 || day > 31) return null;
  const month = ARABIC_MONTHS.get(monthName);
  if (month === undefined) return null;

  let year = yearStr !== undefined ? Number(yearStr) : null;
  if (year !== null && year < 100) year += 2000;

  let normalizedDate: string | null = null;
  if (year !== null) {
    normalizedDate = toIsoDate(year, month, day);
    if (normalizedDate === null) return null;
  }

  return { raw_text: raw, normalized_date: normalizedDate, is_ambiguous: year === null };
}

// ── English month names ────────────────────────────────────────────────────

const ENGLISH_MONTHS: ReadonlyMap<string, number> = new Map([
  ["january", 1],
  ["jan", 1],
  ["february", 2],
  ["feb", 2],
  ["march", 3],
  ["mar", 3],
  ["april", 4],
  ["apr", 4],
  ["may", 5],
  ["june", 6],
  ["jun", 6],
  ["july", 7],
  ["jul", 7],
  ["august", 8],
  ["aug", 8],
  ["september", 9],
  ["sep", 9],
  ["sept", 9],
  ["october", 10],
  ["oct", 10],
  ["november", 11],
  ["nov", 11],
  ["december", 12],
  ["dec", 12],
]);

const ENGLISH_MONTH_NAMES = Array.from(ENGLISH_MONTHS.keys()).join("|");

const ENGLISH_MONTH_DATE_PATTERN = new RegExp(
  `(\\d{1,2})\\s*(?:of\\s+)?(${ENGLISH_MONTH_NAMES})\\s*(\\d{2,4})?`,
  "gi",
);

function parseEnglishMonthDate(match: RegExpMatchArray): DateCandidate | null {
  const raw = match[0];
  const day = Number(match[1]);
  const monthName = match[2].toLowerCase();
  const yearStr = match[3] as string | undefined;

  if (day < 1 || day > 31) return null;
  const month = ENGLISH_MONTHS.get(monthName);
  if (month === undefined) return null;

  let year = yearStr !== undefined ? Number(yearStr) : null;
  if (year !== null && year < 100) year += 2000;

  let normalizedDate: string | null = null;
  if (year !== null) {
    normalizedDate = toIsoDate(year, month, day);
    if (normalizedDate === null) return null;
  }

  return { raw_text: raw, normalized_date: normalizedDate, is_ambiguous: year === null };
}

// ── Hijri month detection (no conversion) ──────────────────────────────────

const HIJRI_MONTH_NAMES = [
  "محرم",
  "صفر",
  "ربيع الأول",
  "ربيع الاول",
  "ربيع الثاني",
  "ربيع الثانى",
  "جمادى الأولى",
  "جمادى الاولى",
  "جمادى الآخرة",
  "جمادى الاخرة",
  "رجب",
  "شعبان",
  "رمضان",
  "شوال",
  "ذو القعدة",
  "ذو الحجة",
];

const HIJRI_PATTERN = new RegExp(
  `\\d{1,2}\\s*(?:من\\s+)?(?:${HIJRI_MONTH_NAMES.join("|")})\\s*\\d{2,4}`,
  "g",
);

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Builds an ISO `YYYY-MM-DD` string, rejecting rollover (e.g. 30 Feb) the same
 * way the Dart extractor does by round-tripping through a UTC calendar date.
 */
function toIsoDate(year: number, month: number, day: number): string | null {
  const constructed = new Date(Date.UTC(year, month - 1, day));
  if (
    constructed.getUTCFullYear() !== year || constructed.getUTCMonth() !== month - 1 ||
    constructed.getUTCDate() !== day
  ) {
    return null;
  }
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${
    String(day).padStart(2, "0")
  }`;
}
