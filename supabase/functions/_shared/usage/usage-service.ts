/**
 * F06-T06 · The daily-limit check.
 *
 * Decides whether a user may start another analysis today, where "today" is an
 * Africa/Cairo calendar day (§27). The reading of the counters is injected, so
 * the decision itself is pure and testable without a database; the atomic
 * reserve/finalize that mutates them is F06-T07.
 */

import {
  type CairoDay,
  cairoDayOf,
  nextCairoResetAfter,
  toCairoIsoString,
} from "../time/cairo-day.ts";

/** A row of `analysis_usage_daily`, or zeroes when the user has none today. */
export interface DailyUsage {
  /** Analyses that completed successfully — quota actually consumed. */
  readonly successfulCount: number;
  /** Slots reserved but not yet finalised (in-flight requests). */
  readonly reservedCount: number;
}

export const NO_USAGE: DailyUsage = Object.freeze({
  successfulCount: 0,
  reservedCount: 0,
});

/** Reads today's counters. Injected so the decision can be tested offline. */
export type UsageReader = (
  userId: string,
  day: CairoDay,
) => Promise<DailyUsage>;

/**
 * The answer to "may this user analyse right now, and what should we tell
 * them?". Field names match the get-usage response in §23 so the endpoint can
 * serialise it directly.
 */
export interface UsageDecision {
  readonly allowed: boolean;
  readonly dailyLimit: number;
  /**
   * Analyses genuinely consumed today. Excludes in-flight reservations,
   * because a request that later fails must not appear to have cost the user
   * anything.
   */
  readonly usedToday: number;
  /**
   * How many the user can still START right now. This DOES subtract in-flight
   * reservations, so it can be lower than `dailyLimit - usedToday` for the few
   * seconds an analysis is running — the honest answer to "can I go now?".
   */
  readonly remainingToday: number;
  /** Cairo-day rollover as ISO-8601 with the real offset (§31 `reset_at`). */
  readonly resetsAt: string;
  /** The Cairo day these numbers describe. */
  readonly day: CairoDay;
}

/**
 * Applies the limit to a set of counters. Pure.
 *
 * Reservations count against the limit. Without that, three requests firing
 * together would each read `successfulCount = 0` and all be admitted, letting a
 * user exceed the daily cap by simply tapping fast.
 *
 * A limit of `0` disables analysis entirely; negative or non-finite limits are
 * treated as `0` rather than trusted, since the value comes from
 * `app_runtime_config` and a bad row should fail closed.
 */
export function evaluateDailyLimit(
  usage: DailyUsage,
  dailyLimit: number,
  now: Date,
): UsageDecision {
  const limit = Number.isFinite(dailyLimit) && dailyLimit > 0 ? Math.floor(dailyLimit) : 0;

  const committed = usage.successfulCount + usage.reservedCount;
  const remaining = Math.max(0, limit - committed);

  return {
    allowed: remaining > 0,
    dailyLimit: limit,
    usedToday: usage.successfulCount,
    remainingToday: remaining,
    resetsAt: toCairoIsoString(nextCairoResetAfter(now)),
    day: cairoDayOf(now),
  };
}

/** Reads the user's counters for the current Cairo day and applies the limit. */
export async function checkDailyLimit(
  readUsage: UsageReader,
  userId: string,
  dailyLimit: number,
  now: Date,
): Promise<UsageDecision> {
  const usage = await readUsage(userId, cairoDayOf(now));
  return evaluateDailyLimit(usage, dailyLimit, now);
}
