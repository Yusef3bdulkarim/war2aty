/**
 * F06-T06 · Africa/Cairo day boundaries.
 *
 * The daily quota is counted per **Cairo calendar day** (§27), so this decides
 * which day an analysis belongs to and when the quota next resets.
 *
 * A fixed UTC offset is explicitly forbidden (§27): Egypt observes DST again
 * since 2023 (+02 EET / +03 EEST), so `+02:00` is wrong for half the year and
 * would hand users a free extra analysis — or deny them one — around midnight.
 * Everything here goes through the IANA `Africa/Cairo` rules instead.
 *
 * The Flutter side (`lib/core/time/cairo_day.dart`) deliberately approximates
 * with a fixed +02:00 for grouping and display only; this module is the
 * authority, and `reset_at` on the wire always comes from here.
 *
 * ── Why "midnight" is not good enough ────────────────────────────────────
 * On a spring-forward date Cairo has no local midnight. In 2026 the clock goes
 * 2026-04-23 23:59:59 +02:00 → 2026-04-24 01:00:00 +03:00, so 00:00–00:59 on
 * the 24th never happens. We therefore compute the *instant* a day begins and
 * format that, which yields a truthful `2026-04-24T01:00:00+03:00` rather than
 * a midnight that did not occur.
 */

export const CAIRO_TIME_ZONE = "Africa/Cairo";

/** `YYYY-MM-DD` — matches the `usage_date` DATE column in `analysis_usage_daily`. */
export type CairoDay = string;

const MINUTE_MS = 60_000;
const HOUR_MS = 3_600_000;

// Reused: constructing an Intl formatter is comparatively expensive.
const PARTS_FORMATTER = new Intl.DateTimeFormat("en-US", {
  timeZone: CAIRO_TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hour12: false,
});

interface WallClock {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function wallClockAt(instant: Date): WallClock {
  const parts = PARTS_FORMATTER.formatToParts(instant);
  const read = (type: Intl.DateTimeFormatPartTypes): number => {
    const value = parts.find((part) => part.type === type)?.value ?? "0";
    return Number(value);
  };

  // Some ICU versions render midnight as hour 24 under hour12:false.
  const hour = read("hour") % 24;

  return {
    year: read("year"),
    month: read("month"),
    day: read("day"),
    hour,
    minute: read("minute"),
    second: read("second"),
  };
}

/** Cairo's UTC offset in milliseconds at a given instant (+02 or +03). */
export function cairoOffsetMsAt(instant: Date): number {
  const wall = wallClockAt(instant);
  const asIfUtc = Date.UTC(
    wall.year,
    wall.month - 1,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
  // Round to the second: the formatter drops milliseconds.
  return asIfUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

function pad(value: number, width = 2): string {
  return String(value).padStart(width, "0");
}

/** The Cairo calendar day an instant falls on, as `YYYY-MM-DD`. */
export function cairoDayOf(instant: Date): CairoDay {
  const wall = wallClockAt(instant);
  return `${pad(wall.year, 4)}-${pad(wall.month)}-${pad(wall.day)}`;
}

function parseDay(day: CairoDay): { year: number; month: number; day: number } {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day);
  if (match === null) {
    throw new RangeError(`Not a YYYY-MM-DD day: ${day}`);
  }
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
  };
}

/**
 * The exact instant a Cairo day begins — the earliest instant whose Cairo date
 * is `day`.
 *
 * On an ordinary day that is local midnight. On a spring-forward day, when
 * midnight does not exist, it is the first moment the date actually reads as
 * `day` (01:00 local in 2026).
 */
export function cairoDayStartInstant(day: CairoDay): Date {
  const { year, month, day: dayOfMonth } = parseDay(day);
  const naiveMidnight = Date.UTC(year, month - 1, dayOfMonth, 0, 0, 0);

  // Two passes: the first guess lands near the target, the second uses the
  // offset actually in force there. This already resolves both Cairo
  // transitions, which happen on whole hours.
  const firstGuess = naiveMidnight - cairoOffsetMsAt(new Date(naiveMidnight));
  let instant = naiveMidnight - cairoOffsetMsAt(new Date(firstGuess));

  // Safety net for tz rules the two passes cannot express (a transition at a
  // non-hour boundary, say). Walks to the true edge in bounded steps rather
  // than trusting the arithmetic blindly.
  const STEP_MS = 15 * MINUTE_MS;
  const MAX_STEPS = 12; // ±3h covers any plausible offset change.

  let steps = 0;
  while (cairoDayOf(new Date(instant)) < day && steps < MAX_STEPS) {
    instant += STEP_MS;
    steps += 1;
  }
  steps = 0;
  while (cairoDayOf(new Date(instant - MINUTE_MS)) >= day && steps < MAX_STEPS * 15) {
    instant -= MINUTE_MS;
    steps += 1;
  }

  return new Date(instant);
}

/** The day after `day`, as `YYYY-MM-DD`. */
export function nextCairoDay(day: CairoDay): CairoDay {
  const { year, month, day: dayOfMonth } = parseDay(day);
  const next = new Date(Date.UTC(year, month - 1, dayOfMonth + 1));
  return `${pad(next.getUTCFullYear(), 4)}-${pad(next.getUTCMonth() + 1)}-${
    pad(next.getUTCDate())
  }`;
}

/**
 * When the quota next resets: the instant the Cairo day *after* `instant`
 * begins.
 */
export function nextCairoResetAfter(instant: Date): Date {
  return cairoDayStartInstant(nextCairoDay(cairoDayOf(instant)));
}

/**
 * Formats an instant as ISO-8601 carrying Cairo's real offset, e.g.
 * `2026-07-27T00:00:00+03:00`.
 *
 * This is what `details.reset_at` sends (§31). The offset is whatever is
 * actually in force at that instant — never a hard-coded `+02:00`.
 */
export function toCairoIsoString(instant: Date): string {
  const wall = wallClockAt(instant);
  const offsetMs = cairoOffsetMsAt(instant);

  const sign = offsetMs < 0 ? "-" : "+";
  const absolute = Math.abs(offsetMs);
  const offsetHours = Math.floor(absolute / HOUR_MS);
  const offsetMinutes = Math.floor((absolute % HOUR_MS) / MINUTE_MS);

  const date = `${pad(wall.year, 4)}-${pad(wall.month)}-${pad(wall.day)}`;
  const time = `${pad(wall.hour)}:${pad(wall.minute)}:${pad(wall.second)}`;

  return `${date}T${time}${sign}${pad(offsetHours)}:${pad(offsetMinutes)}`;
}
