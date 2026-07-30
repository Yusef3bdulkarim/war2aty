/**
 * F06-T13 · The get-usage handler.
 *
 * Answers "how many analyses do I have left today?" so the Home screen can say
 * so before the user photographs anything, and so the app's local counter can
 * be corrected after a re-install or a second device.
 *
 * Read-only by design. It deliberately does NOT sweep expired reservations:
 * that is a write, and doing it on a read path would let an unauthenticated-ish
 * poll drive database work. A crashed request can therefore make
 * `remaining_today` look one lower than it will be, for at most the reservation
 * TTL (~35s) — the next `reserve_analysis_slot` sweeps the user's stale rows
 * anyway (F06-T07).
 */

import { apiErrorForAuthFailure } from "../errors/api-error.ts";
import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import type { RuntimeConfig } from "../config/runtime-config.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { jsonResponse } from "../http/response.ts";
import { logEvent } from "../observability/log.ts";
import { checkDailyLimit, type UsageReader } from "./usage-service.ts";

/**
 * The get-usage body. Field names mirror `DailyUsage` in
 * `lib/core/usage/daily_usage.dart` so F06-T14 maps one to one.
 */
export interface UsageResponseBody {
  readonly schema_version: string;
  /** The Africa/Cairo day these numbers describe, `YYYY-MM-DD` (§27). */
  readonly usage_date: string;
  readonly daily_limit: number;
  /** Analyses actually consumed. Excludes anything still in flight. */
  readonly used_today: number;
  /**
   * How many may be STARTED right now. This does subtract in-flight
   * reservations, so it can briefly be lower than `daily_limit - used_today`.
   */
  readonly remaining_today: number;
  /** Cairo-day rollover, ISO-8601 with the real offset (+02 or +03). */
  readonly resets_at: string;
  /** The kill switch, so the app can explain a disabled service before it tries. */
  readonly analysis_enabled: boolean;
}

export interface UsageDependencies {
  readonly verifyToken: TokenVerifier;
  readonly loadConfig: () => Promise<RuntimeConfig>;
  readonly readUsage: UsageReader;
  readonly now: () => Date;
}

export function createUsageHandler(
  dependencies: UsageDependencies,
): EndpointHandler {
  const { verifyToken, loadConfig, readUsage, now } = dependencies;

  return async ({ request, requestId }): Promise<Response> => {
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    const config = await loadConfig();
    const instant = now();

    // The user id comes from the verified token, never from the request — a
    // caller must not be able to read someone else's quota by asking.
    const decision = await checkDailyLimit(
      readUsage,
      auth.user.id,
      config.dailyLimit,
      instant,
    );

    const body: UsageResponseBody = {
      schema_version: config.schemaVersion,
      usage_date: decision.day,
      daily_limit: decision.dailyLimit,
      used_today: decision.usedToday,
      remaining_today: decision.remainingToday,
      resets_at: decision.resetsAt,
      analysis_enabled: config.analysisEnabled,
    };

    logEvent("usage.read", {
      request_id: requestId,
      usage_date: body.usage_date,
      used_today: body.used_today,
      remaining_today: body.remaining_today,
    });

    return jsonResponse(body, { requestId });
  };
}
