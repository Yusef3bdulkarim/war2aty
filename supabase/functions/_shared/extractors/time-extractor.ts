/**
 * F13-T05 · Time candidate extraction (Azure text path).
 *
 * TypeScript port of `lib/features/ocr/domain/services/time_extractor.dart`,
 * field-for-field.
 *
 * Supports:
 * - 24h format: HH:MM, HH.MM
 * - 12h format with Arabic markers: صباحاً/ص (AM), مساءً/م (PM)
 * - 12h format with English markers: AM/PM, a.m./p.m.
 */

import type { TimeCandidate } from "../prompts/analysis-prompt.ts";

const TIME_PATTERN = /(\d{1,2})\s*[:.]\s*(\d{2})(?:\s*(صباح[اً]*|مساء[ًا]*|ص|م|[AaPp]\.?[Mm]\.?))?/g;

export function extractTimes(text: string): TimeCandidate[] {
  const candidates: TimeCandidate[] = [];

  for (const match of text.matchAll(TIME_PATTERN)) {
    const candidate = parseTime(match);
    if (candidate !== null) candidates.push(candidate);
  }

  return candidates;
}

function parseTime(match: RegExpMatchArray): TimeCandidate | null {
  const raw = match[0];
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const period = match[3]?.trim();

  if (minute > 59) return null;

  let isAmbiguous = false;

  if (period !== undefined) {
    const isPm = isPmMarker(period);
    const isAm = isAmMarker(period);

    if (hour < 1 || hour > 12) return null;

    if (isPm && hour !== 12) {
      hour += 12;
    } else if (isAm && hour === 12) {
      hour = 0;
    }
  } else {
    if (hour > 23) return null;
    // Without AM/PM, times 1:00-12:59 are ambiguous (could be AM or PM).
    if (hour >= 1 && hour <= 12) isAmbiguous = true;
  }

  return { raw_text: raw, hour, minute, is_ambiguous: isAmbiguous };
}

function isPmMarker(marker: string): boolean {
  const lower = marker.toLowerCase();
  return lower.startsWith("مساء") || lower === "م" || lower.startsWith("pm") ||
    lower.startsWith("p.m");
}

function isAmMarker(marker: string): boolean {
  const lower = marker.toLowerCase();
  return lower.startsWith("صباح") || lower === "ص" || lower.startsWith("am") ||
    lower.startsWith("a.m");
}
