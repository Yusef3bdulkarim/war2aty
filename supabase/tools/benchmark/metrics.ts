/**
 * F20-T08 · Scoring for the OCR and analysis benchmarks.
 *
 * Pure functions only, so every number T09 gates on is unit-tested
 * (`tests/unit/benchmark-metrics.test.ts`) rather than trusted.
 *
 * Ported from F17's `ocr-benchmark.ts` (normalisation, edit distance, critical
 * recall), which F20 takes without merging F17 (decision D7), and extended
 * with the per-script, digit, precision and loss metrics T09 needs.
 */

// ── normalisation ─────────────────────────────────────────────────────────
//
// Comparing Arabic byte-for-byte would score cosmetic differences as errors:
// an OCR engine may return a bare alef where the page has a hamza-carrying
// one, and diacritics are optional in print. Normalising both sides keeps CER
// a measure of misreading rather than of orthographic variation.

const ARABIC_DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭ]/g;
const TATWEEL = /ـ/g;

export function normalise(text: string): string {
  return text
    .replace(ARABIC_DIACRITICS, "")
    .replace(TATWEEL, "")
    .replace(/[آأإٱ]/g, "ا") // alef forms → bare alef
    .replace(/ى/g, "ي") // alef maqsura → ya
    .replace(/ة/g, "ه") // ta marbuta → ha
    .replace(
      /[٠-٩]/g,
      (d) => String.fromCharCode(d.charCodeAt(0) - 0x0660 + 0x30),
    )
    .replace(
      /[۰-۹]/g,
      (d) => String.fromCharCode(d.charCodeAt(0) - 0x06F0 + 0x30),
    )
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

/**
 * A date or an amount is one compact token whose internal spacing carries no
 * meaning: `10, 99€` for `10,99€` is a correct reading. Digits, separators
 * and their order still have to agree exactly.
 */
export function compact(text: string): string {
  return normalise(text).replace(/\s+/g, "");
}

// ── edit distance ─────────────────────────────────────────────────────────

/** Levenshtein distance, two rows rather than a full matrix. */
export function editDistance(
  a: readonly string[],
  b: readonly string[],
): number {
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;

  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  let current = new Array<number>(b.length + 1);

  for (let i = 1; i <= a.length; i++) {
    current[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const substitution = previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1);
      current[j] = Math.min(substitution, previous[j] + 1, current[j - 1] + 1);
    }
    [previous, current] = [current, previous];
  }

  return previous[b.length];
}

/** Edits per expected unit. `null` when nothing was expected. Can exceed 1. */
export function errorRate(
  expected: readonly string[],
  actual: readonly string[],
): number | null {
  if (expected.length === 0) return null;
  return editDistance(expected, actual) / expected.length;
}

/** Character error rate, over normalised text. */
export function cer(truth: string, ocr: string): number | null {
  return errorRate([...normalise(truth)], [...normalise(ocr)]);
}

/** Word error rate, over normalised text. */
export function wer(truth: string, ocr: string): number | null {
  const words = (text: string) => normalise(text).split(" ").filter(Boolean);
  return errorRate(words(truth), words(ocr));
}

const LETTER = /\p{L}/u;
const SCRIPT = {
  arabic: /\p{Script=Arabic}/u,
  latin: /\p{Script=Latin}/u,
} as const;

/**
 * CER over one script's letters only, each side filtered to that script.
 * `null` when the truth has none. This is what shows whether a provider is
 * strong on Arabic and weak on the English beside it, or the reverse.
 */
export function scriptCer(
  truth: string,
  ocr: string,
  script: "arabic" | "latin",
): number | null {
  const letters = (text: string) =>
    [...normalise(text)].filter((c) => LETTER.test(c) && SCRIPT[script].test(c));
  return errorRate(letters(truth), letters(ocr));
}

/**
 * `1 − CER` over the digit sequence alone, floored at 0. Both digit systems
 * are folded first, so a page printed in ٠-٩ and read back in 0-9 scores as
 * correct: T13 folds them before the extractors anyway. `null` when the truth
 * carries no digits.
 */
export function digitAccuracy(truth: string, ocr: string): number | null {
  const digits = (text: string) => [...normalise(text)].filter((c) => c >= "0" && c <= "9");
  const rate = errorRate(digits(truth), digits(ocr));
  return rate === null ? null : Math.max(0, 1 - rate);
}

// ── critical fields (dates and amounts, as printed) ───────────────────────

export interface CriticalFieldScore {
  /** Share of the truth's printed dates+amounts found in the OCR text. */
  readonly recall: number | null;
  /**
   * Share of the extractors' date+amount candidates that match a truth value.
   * `null` when the extractors found none.
   */
  readonly precision: number | null;
  /** Truth values the OCR text does not contain: the reader's loss. */
  readonly ocrLoss: number;
  /** Truth values the OCR text contains but no candidate caught: the extractors' loss. */
  readonly extractorLoss: number;
  readonly expected: number;
}

/** Two printed values name the same field when one contains the other, compacted. */
function sameField(a: string, b: string): boolean {
  const x = compact(a);
  const y = compact(b);
  if (x.length === 0 || y.length === 0) return false;
  return x.includes(y) || y.includes(x);
}

/**
 * Scores what the OCR and the extractors recovered of the fields the app
 * exists to get right. Matched on compacted strings rather than on parsed
 * values, so this scores the READING; the extractors' parsing is what
 * `extractorLoss` isolates.
 */
export function criticalFields(input: {
  readonly truthValues: readonly string[];
  readonly ocrText: string;
  readonly candidateRawTexts: readonly string[];
}): CriticalFieldScore {
  const { truthValues, ocrText, candidateRawTexts } = input;
  const haystack = compact(ocrText);

  let found = 0;
  let ocrLoss = 0;
  let extractorLoss = 0;
  for (const value of truthValues) {
    const needle = compact(value);
    if (needle.length === 0 || !haystack.includes(needle)) {
      ocrLoss += 1;
      continue;
    }
    found += 1;
    if (!candidateRawTexts.some((raw) => sameField(raw, value))) {
      extractorLoss += 1;
    }
  }

  const matched = candidateRawTexts.filter((raw) => truthValues.some((v) => sameField(raw, v)));

  return {
    recall: truthValues.length === 0 ? null : found / truthValues.length,
    precision: candidateRawTexts.length === 0 ? null : matched.length / candidateRawTexts.length,
    ocrLoss,
    extractorLoss,
    expected: truthValues.length,
  };
}

// ── analysis ──────────────────────────────────────────────────────────────

export interface PrecisionRecall {
  readonly precision: number | null;
  readonly recall: number | null;
}

/** Set precision/recall with a caller-supplied equality. Duplicates count once. */
export function precisionRecall<T>(
  predicted: readonly T[],
  expected: readonly T[],
  same: (a: T, b: T) => boolean,
): PrecisionRecall {
  const unique = (values: readonly T[]) =>
    values.filter((v, i) => values.findIndex((w) => same(v, w)) === i);
  const p = unique(predicted);
  const e = unique(expected);

  const hits = p.filter((v) => e.some((w) => same(v, w))).length;
  return {
    precision: p.length === 0 ? null : hits / p.length,
    recall: e.length === 0 ? null : hits / e.length,
  };
}

/** Amounts are equal when their values are, to float precision. */
export function sameAmount(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-9;
}

/** Share of letters that are Arabic script. `null` when there are no letters. */
export function arabicLetterShare(text: string): number | null {
  let letters = 0;
  let arabic = 0;
  for (const character of text) {
    if (!LETTER.test(character)) continue;
    letters += 1;
    if (SCRIPT.arabic.test(character)) arabic += 1;
  }
  return letters === 0 ? null : arabic / letters;
}

// ── aggregation ───────────────────────────────────────────────────────────

/** Mean of the values that exist. `null` when none do. */
export function mean(values: readonly (number | null)[]): number | null {
  const present = values.filter((v): v is number => v !== null);
  if (present.length === 0) return null;
  return present.reduce((a, b) => a + b, 0) / present.length;
}

/** Nearest-rank percentile, `p` in (0, 100]. `null` for no values. */
export function percentile(
  values: readonly number[],
  p: number,
): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.ceil((p / 100) * sorted.length);
  return sorted[Math.min(sorted.length, Math.max(1, rank)) - 1];
}

/** Share of `true` among the values that exist. `null` when none do. */
export function rate(values: readonly (boolean | null)[]): number | null {
  return mean(values.map((v) => (v === null ? null : v ? 1 : 0)));
}

export function percent(value: number | null): string {
  return value === null ? "  —  " : `${(value * 100).toFixed(1)}%`.padStart(6);
}
