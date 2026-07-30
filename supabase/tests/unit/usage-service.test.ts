/**
 * F06-T06 · Tests for the daily-limit decision.
 */

import { assertEquals } from "jsr:@std/assert@1";

import {
  checkDailyLimit,
  type DailyUsage,
  evaluateDailyLimit,
  NO_USAGE,
  type UsageReader,
} from "../../functions/_shared/usage/usage-service.ts";

const NOON_SUMMER = new Date("2026-07-26T09:00:00Z"); // 12:00 in Cairo
const DEFAULT_LIMIT = 3;

function usage(successfulCount: number, reservedCount = 0): DailyUsage {
  return { successfulCount, reservedCount };
}

// ── the limit ─────────────────────────────────────────────────────────────

Deno.test("a fresh day allows analysis and reports the full quota", () => {
  const decision = evaluateDailyLimit(NO_USAGE, DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(decision.allowed, true);
  assertEquals(decision.usedToday, 0);
  assertEquals(decision.remainingToday, 3);
  assertEquals(decision.dailyLimit, 3);
});

Deno.test("partial use leaves the balance", () => {
  const decision = evaluateDailyLimit(usage(1), DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(decision.allowed, true);
  assertEquals(decision.usedToday, 1);
  assertEquals(decision.remainingToday, 2);
});

Deno.test("the limit blocks the fourth analysis", () => {
  const decision = evaluateDailyLimit(usage(3), DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(decision.allowed, false);
  assertEquals(decision.remainingToday, 0);
});

Deno.test("in-flight reservations count against the limit", () => {
  // Otherwise three simultaneous taps all read successfulCount = 0 and are all
  // admitted, letting a user blow past the cap by tapping fast.
  const decision = evaluateDailyLimit(usage(2, 1), DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(decision.allowed, false);
  assertEquals(decision.remainingToday, 0);
});

Deno.test("a reservation lowers what can be started but not what was used", () => {
  const decision = evaluateDailyLimit(usage(1, 1), DEFAULT_LIMIT, NOON_SUMMER);

  // A request still running has cost the user nothing yet...
  assertEquals(decision.usedToday, 1);
  // ...but they cannot start three more.
  assertEquals(decision.remainingToday, 1);
  assertEquals(decision.allowed, true);
});

Deno.test("remaining never goes negative if counters overshoot", () => {
  // Defensive: a stale reservation sweep or a bug must not produce -1.
  const decision = evaluateDailyLimit(usage(5, 2), DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(decision.remainingToday, 0);
  assertEquals(decision.allowed, false);
});

// ── limit values from runtime config ──────────────────────────────────────

Deno.test("a limit of zero disables analysis", () => {
  const decision = evaluateDailyLimit(NO_USAGE, 0, NOON_SUMMER);

  assertEquals(decision.allowed, false);
  assertEquals(decision.remainingToday, 0);
});

Deno.test("a nonsense limit fails closed rather than open", () => {
  // The value comes from app_runtime_config; a bad row must not grant
  // unlimited analyses.
  for (const bad of [-1, Number.NaN, Number.POSITIVE_INFINITY]) {
    const decision = evaluateDailyLimit(NO_USAGE, bad, NOON_SUMMER);
    assertEquals(decision.allowed, false, `limit ${bad} must not allow`);
    assertEquals(decision.dailyLimit, 0);
  }
});

Deno.test("a fractional limit is floored", () => {
  assertEquals(evaluateDailyLimit(NO_USAGE, 3.9, NOON_SUMMER).dailyLimit, 3);
});

Deno.test("a raised limit takes effect immediately", () => {
  // Runtime config exists so the cap can change without an app release.
  const decision = evaluateDailyLimit(usage(3), 5, NOON_SUMMER);

  assertEquals(decision.allowed, true);
  assertEquals(decision.remainingToday, 2);
});

// ── the Cairo day in the decision ─────────────────────────────────────────

Deno.test("the decision reports the Cairo day and its reset", () => {
  const decision = evaluateDailyLimit(NO_USAGE, DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(decision.day, "2026-07-26");
  assertEquals(decision.resetsAt, "2026-07-27T00:00:00+03:00");
});

Deno.test("late-evening UTC is already the next Cairo day", () => {
  // 22:30Z in summer is 01:30 tomorrow in Cairo — a fresh quota.
  const decision = evaluateDailyLimit(
    NO_USAGE,
    DEFAULT_LIMIT,
    new Date("2026-07-26T22:30:00Z"),
  );

  assertEquals(decision.day, "2026-07-27");
  assertEquals(decision.resetsAt, "2026-07-28T00:00:00+03:00");
});

Deno.test("the reset offset follows DST, not a fixed +02:00", () => {
  const winter = evaluateDailyLimit(
    NO_USAGE,
    DEFAULT_LIMIT,
    new Date("2026-01-15T12:00:00Z"),
  );

  assertEquals(winter.resetsAt, "2026-01-16T00:00:00+02:00");
});

// ── reading the counters ──────────────────────────────────────────────────

Deno.test("checkDailyLimit reads the counters for the current Cairo day", async () => {
  let requestedDay: string | undefined;
  const reader: UsageReader = (_userId, day) => {
    requestedDay = day;
    return Promise.resolve(usage(2));
  };

  const decision = await checkDailyLimit(
    reader,
    "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
    DEFAULT_LIMIT,
    new Date("2026-07-26T22:30:00Z"),
  );

  // Must ask for the Cairo day, not the UTC one.
  assertEquals(requestedDay, "2026-07-27");
  assertEquals(decision.remainingToday, 1);
});

Deno.test("checkDailyLimit passes the user id through untouched", async () => {
  let seenUserId: string | undefined;
  const reader: UsageReader = (userId) => {
    seenUserId = userId;
    return Promise.resolve(NO_USAGE);
  };

  await checkDailyLimit(reader, "user-123", DEFAULT_LIMIT, NOON_SUMMER);

  assertEquals(seenUserId, "user-123");
});
