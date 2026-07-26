/**
 * F06-T06 · Tests for the Cairo day boundary.
 *
 * Egypt observes DST again since 2023, so these pin behaviour across real
 * transitions. Expected values were taken from the IANA rules: DST starts on
 * the last Friday of April and ends on the last Thursday of October.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  cairoDayOf,
  cairoDayStartInstant,
  cairoOffsetMsAt,
  nextCairoDay,
  nextCairoResetAfter,
  toCairoIsoString,
} from "../../functions/_shared/time/cairo-day.ts";

const HOUR_MS = 3_600_000;

// ── offsets ───────────────────────────────────────────────────────────────

Deno.test("Cairo is UTC+2 in winter and UTC+3 in summer", () => {
  assertEquals(cairoOffsetMsAt(new Date("2026-01-15T12:00:00Z")), 2 * HOUR_MS);
  assertEquals(cairoOffsetMsAt(new Date("2026-07-15T12:00:00Z")), 3 * HOUR_MS);
});

Deno.test("the offset flips exactly at the 2026 spring-forward instant", () => {
  // 2026-04-23T22:00Z: 23:59:59 +02 becomes 01:00:00 +03.
  assertEquals(cairoOffsetMsAt(new Date("2026-04-23T21:59:59Z")), 2 * HOUR_MS);
  assertEquals(cairoOffsetMsAt(new Date("2026-04-23T22:00:00Z")), 3 * HOUR_MS);
});

Deno.test("the offset flips exactly at the 2026 fall-back instant", () => {
  assertEquals(cairoOffsetMsAt(new Date("2026-10-29T20:59:59Z")), 3 * HOUR_MS);
  assertEquals(cairoOffsetMsAt(new Date("2026-10-29T21:00:00Z")), 2 * HOUR_MS);
});

// ── which day an instant belongs to ───────────────────────────────────────

Deno.test("cairoDayOf uses Cairo local date, not UTC date", () => {
  // 22:30Z in summer is already 01:30 the NEXT day in Cairo. Counting this as
  // the UTC day would hand the user a second daily quota before midnight.
  assertEquals(cairoDayOf(new Date("2026-07-26T22:30:00Z")), "2026-07-27");
  assertEquals(cairoDayOf(new Date("2026-07-26T20:30:00Z")), "2026-07-26");
});

Deno.test("cairoDayOf handles the winter boundary", () => {
  // Winter is +02, so the day rolls at 22:00Z.
  assertEquals(cairoDayOf(new Date("2026-01-15T21:59:59Z")), "2026-01-15");
  assertEquals(cairoDayOf(new Date("2026-01-15T22:00:00Z")), "2026-01-16");
});

Deno.test("cairoDayOf pads single-digit months and days", () => {
  assertEquals(cairoDayOf(new Date("2026-03-05T10:00:00Z")), "2026-03-05");
});

// ── day start ─────────────────────────────────────────────────────────────

Deno.test("an ordinary summer day starts at local midnight", () => {
  assertEquals(
    cairoDayStartInstant("2026-07-27").toISOString(),
    "2026-07-26T21:00:00.000Z",
  );
});

Deno.test("an ordinary winter day starts at local midnight", () => {
  assertEquals(
    cairoDayStartInstant("2026-01-16").toISOString(),
    "2026-01-15T22:00:00.000Z",
  );
});

Deno.test("a spring-forward day starts at 01:00 because midnight never happens", () => {
  // The clock jumps 2026-04-23 23:59:59+02 -> 2026-04-24 01:00:00+03.
  const start = cairoDayStartInstant("2026-04-24");

  assertEquals(start.toISOString(), "2026-04-23T22:00:00.000Z");
  assertEquals(cairoDayOf(start), "2026-04-24");
  // One millisecond earlier must still be the previous day.
  assertEquals(cairoDayOf(new Date(start.getTime() - 1)), "2026-04-23");
});

Deno.test("a fall-back day starts once, despite the repeated hour", () => {
  // 23:00-23:59 on the 29th occurs twice; the 30th still begins cleanly.
  const start = cairoDayStartInstant("2026-10-30");

  assertEquals(start.toISOString(), "2026-10-29T22:00:00.000Z");
  assertEquals(cairoDayOf(start), "2026-10-30");
  assertEquals(cairoDayOf(new Date(start.getTime() - 1)), "2026-10-29");
});

Deno.test("day start is the earliest instant of that day, always", () => {
  // Property check across a year, including both transitions.
  for (const day of ["2026-01-01", "2026-04-24", "2026-06-15", "2026-10-30", "2026-12-31"]) {
    const start = cairoDayStartInstant(day);
    assertEquals(cairoDayOf(start), day, `${day} start must be in the day`);
    assertEquals(
      cairoDayOf(new Date(start.getTime() - 1)) < day,
      true,
      `${day} start must be the first instant`,
    );
  }
});

Deno.test("cairoDayStartInstant rejects a malformed day", () => {
  assertThrows(() => cairoDayStartInstant("26-01-01"), RangeError);
  assertThrows(() => cairoDayStartInstant("2026-1-1"), RangeError);
  assertThrows(() => cairoDayStartInstant("not-a-day"), RangeError);
});

// ── next day / reset ──────────────────────────────────────────────────────

Deno.test("nextCairoDay rolls month, year and leap day", () => {
  assertEquals(nextCairoDay("2026-07-26"), "2026-07-27");
  assertEquals(nextCairoDay("2026-07-31"), "2026-08-01");
  assertEquals(nextCairoDay("2026-12-31"), "2027-01-01");
  assertEquals(nextCairoDay("2028-02-28"), "2028-02-29");
});

Deno.test("the quota resets at the start of the next Cairo day", () => {
  const reset = nextCairoResetAfter(new Date("2026-07-26T12:00:00Z"));

  assertEquals(reset.toISOString(), "2026-07-26T21:00:00.000Z");
  assertEquals(cairoDayOf(reset), "2026-07-27");
});

Deno.test("just before rollover the reset is imminent, not a day away", () => {
  // 20:59Z summer = 23:59 Cairo. Reset must be one minute out.
  const now = new Date("2026-07-26T20:59:00Z");
  const reset = nextCairoResetAfter(now);

  assertEquals(reset.getTime() - now.getTime(), 60_000);
});

Deno.test("just after rollover the reset is a full day away", () => {
  const now = new Date("2026-07-26T21:00:00Z");
  const reset = nextCairoResetAfter(now);

  assertEquals(reset.getTime() - now.getTime(), 24 * HOUR_MS);
});

// ── ISO formatting ────────────────────────────────────────────────────────

Deno.test("toCairoIsoString carries the real summer offset", () => {
  assertEquals(
    toCairoIsoString(new Date("2026-07-26T21:00:00Z")),
    "2026-07-27T00:00:00+03:00",
  );
});

Deno.test("toCairoIsoString carries the real winter offset", () => {
  assertEquals(
    toCairoIsoString(new Date("2026-01-15T22:00:00Z")),
    "2026-01-16T00:00:00+02:00",
  );
});

Deno.test("toCairoIsoString tells the truth on a spring-forward day", () => {
  // Reporting "2026-04-24T00:00:00+02:00" would name a time that never
  // existed; the day really begins at 01:00 +03:00.
  assertEquals(
    toCairoIsoString(cairoDayStartInstant("2026-04-24")),
    "2026-04-24T01:00:00+03:00",
  );
});

Deno.test("a formatted reset parses back to the same instant", () => {
  // The client does DateTime.parse on this string, so it must round-trip.
  for (const iso of ["2026-07-26T12:00:00Z", "2026-01-15T12:00:00Z", "2026-04-23T22:00:00Z"]) {
    const reset = nextCairoResetAfter(new Date(iso));
    assertEquals(new Date(toCairoIsoString(reset)).getTime(), reset.getTime());
  }
});
