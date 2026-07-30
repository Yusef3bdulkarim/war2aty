/**
 * F06-T12 · Matching model output back to the page.
 *
 * Verification asks one question: is this value actually ON the paper? Answering
 * it means comparing a clean model value against messy OCR text, so both sides
 * are normalised the same way first.
 *
 * The client normalises Arabic-Indic digits before sending (`TextNormalizer` in
 * lib/features/ocr), but we redo it here. The backend must not trust the client
 * to have sanitised its input — a stale build, or a crafted request, would
 * otherwise slip past every check below.
 */

/** ٠-٩ and ۰-۹ → 0-9. */
export function normaliseDigits(text: string): string {
  let out = "";
  for (const character of text) {
    const code = character.codePointAt(0)!;
    if (code >= 0x0660 && code <= 0x0669) {
      out += String.fromCharCode(code - 0x0660 + 0x30);
    } else if (code >= 0x06f0 && code <= 0x06f9) {
      out += String.fromCharCode(code - 0x06f0 + 0x30);
    } else {
      out += character;
    }
  }
  return out;
}

/**
 * Folds the cosmetic differences between a printed value and a reported one:
 * Arabic decimal/thousands marks, tatweel, and separator characters.
 */
export function normaliseForMatching(text: string): string {
  return normaliseDigits(text)
    // Arabic decimal separator ٫ and thousands separator ٬ / ،
    .replaceAll("٫", ".")
    .replaceAll("٬", "")
    .replaceAll("،", "")
    // Tatweel is decorative and OCR emits it unpredictably.
    .replaceAll("ـ", "")
    .toLowerCase();
}

/** Every number-like token in the text, parsed. */
export function extractNumbers(text: string): number[] {
  const normalised = normaliseForMatching(text);
  const numbers: number[] = [];

  // Thousands separators are stripped so "1,250.75" reads as one number.
  for (const match of normalised.matchAll(/\d[\d,\s]*(?:\.\d+)?/g)) {
    const candidate = match[0].replaceAll(",", "").replaceAll(/\s/g, "");
    if (candidate.length === 0) continue;
    const parsed = Number(candidate);
    if (Number.isFinite(parsed)) numbers.push(parsed);
  }

  return numbers;
}

/**
 * Whether `value` appears among the numbers in `text`.
 *
 * Compared numerically, not textually: the model may report 850.5 for a printed
 * "850.50", and both are the same amount. A tiny epsilon absorbs float
 * representation, nothing more — 850.5 must never match 851.
 */
export function containsNumber(text: string, value: number): boolean {
  if (!Number.isFinite(value)) return false;
  return extractNumbers(text).some(
    (candidate) => Math.abs(candidate - value) < 1e-9,
  );
}

/** Digits only — for comparing account numbers, phones and references. */
export function digitsOf(text: string): string {
  return normaliseDigits(text).replaceAll(/\D/g, "");
}

/**
 * Whether a reported digit string appears in the text.
 *
 * Compares digit sequences with separators removed, so "0100-123-4567" on the
 * page matches "01001234567" from the model.
 */
export function containsDigitSequence(text: string, value: string): boolean {
  const needle = digitsOf(value);
  if (needle.length === 0) return false;
  return digitsOf(text).includes(needle);
}

/**
 * Loose containment for free text: normalised, whitespace-collapsed substring.
 *
 * Used for labels and names, where OCR spacing is unreliable.
 */
export function containsText(haystack: string, needle: string): boolean {
  const collapse = (value: string) => normaliseForMatching(value).replaceAll(/\s+/g, " ").trim();

  const trimmed = collapse(needle);
  if (trimmed.length === 0) return false;
  return collapse(haystack).includes(trimmed);
}
