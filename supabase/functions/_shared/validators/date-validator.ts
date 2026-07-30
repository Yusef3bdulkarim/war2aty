/**
 * F06-T12 · Date verification (§34).
 *
 * Dates matter more than anything else here: the app exists so someone does not
 * miss a payment deadline or a hospital appointment. A wrong date is the most
 * damaging output this system can produce.
 *
 * Strict structured output cannot enforce a format — Groq's schema subset has
 * no `pattern` or `format` keyword — so `"date": "next Tuesday"` would satisfy
 * the schema perfectly. The format check therefore has to live here.
 */

import type { ModelDate } from "../schemas/groq-output.schema.ts";
import { digitsOf, normaliseDigits } from "./text-matching.ts";
import type { VerificationSources } from "./number-validator.ts";

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const ISO_TIME = /^([01]\d|2[0-3]):([0-5]\d)$/;

export interface DateVerdict {
  /** The date is a real calendar date in ISO form. */
  readonly wellFormed: boolean;
  /** The date's components can be found in the source text. */
  readonly traceable: boolean;
  /** The stated time is present on the page (or there is no time). */
  readonly timeSupported: boolean;
  /** The date has already passed. */
  readonly inPast: boolean;
}

/** ISO-8601 `YYYY-MM-DD` naming a date that actually exists. */
export function isWellFormedDate(value: string): boolean {
  const match = ISO_DATE.exec(value);
  if (match === null) return false;

  const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;

  // Round-tripping rejects 2026-02-30 and 2027-02-29, which the range check
  // above happily accepts.
  const constructed = new Date(Date.UTC(year, month - 1, day));
  return constructed.getUTCFullYear() === year &&
    constructed.getUTCMonth() === month - 1 &&
    constructed.getUTCDate() === day;
}

export function isWellFormedTime(value: string): boolean {
  return ISO_TIME.test(value);
}

/**
 * Whether the date can be found in the source material.
 *
 * OCR spells dates every possible way — `15/4/2026`, `2026/04/15`, `١٥-٤-٢٠٢٦` —
 * so matching the ISO string directly would fail constantly. Instead we check
 * that the day, month and year digits all appear, which catches the case that
 * matters: a date the model invented outright.
 *
 * A normalised candidate that already equals the date is accepted immediately;
 * the on-device extractor did the parsing work.
 */
export function isDateTraceable(
  date: string,
  sources: VerificationSources,
): boolean {
  const match = ISO_DATE.exec(date);
  if (match === null) return false;

  const [, year, month, day] = match;

  for (const candidate of sources.candidates.dates) {
    if (candidate.normalized_date === date) return true;
  }

  const haystack = digitsOf(
    sources.ocrText + "\n" +
      sources.candidates.dates.map((c) => c.raw_text).join("\n"),
  );

  // Unpadded forms are what a person writes: 2026-04-05 is printed "5/4/2026".
  const appears = (value: string) =>
    haystack.includes(value) || haystack.includes(String(Number(value)));

  // The year is the part the model is most likely to have assumed (§33 rule
  // 14), so it must be present, not merely plausible.
  return appears(year) && appears(month) && appears(day);
}

/** Whether a stated time actually appears in the source. */
export function isTimeSupported(
  time: string | null,
  sources: VerificationSources,
): boolean {
  // No time claimed is not a failure — most documents state none.
  if (time === null) return true;
  if (!isWellFormedTime(time)) return false;

  const [hour, minute] = time.split(":");

  for (const candidate of sources.candidates.times) {
    if (candidate.hour === Number(hour) && candidate.minute === Number(minute)) {
      return true;
    }
  }

  const text = normaliseDigits(sources.ocrText);
  // Both zero-padded and bare forms: "9:30" and "09:30".
  return text.includes(`${hour}:${minute}`) ||
    text.includes(`${Number(hour)}:${minute}`);
}

/** Verifies one reported date against the page. */
export function verifyDate(
  date: ModelDate,
  sources: VerificationSources,
  now: Date,
): DateVerdict {
  const wellFormed = isWellFormedDate(date.date);

  return {
    wellFormed,
    traceable: wellFormed && isDateTraceable(date.date, sources),
    timeSupported: isTimeSupported(date.time, sources),
    // Compared at day granularity: a deadline is missed the day after, not the
    // instant after midnight in some timezone.
    inPast: wellFormed && date.date < isoDay(now),
  };
}

function isoDay(instant: Date): string {
  return instant.toISOString().slice(0, 10);
}
