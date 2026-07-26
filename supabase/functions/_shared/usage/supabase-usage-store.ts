/**
 * F06-T07 · The Postgres-backed {@link SlotStore} and {@link UsageReader}.
 *
 * Separated from `slot-reservation.ts` and `usage-service.ts` so that logic
 * stays testable without a database, matching the split used for auth.
 *
 * Uses the SERVICE ROLE key: these tables have RLS on with zero policies and
 * no client grants (§26), so nothing but the service role can reach them. That
 * key must never leave the Edge Function.
 */

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import type { CairoDay } from "../time/cairo-day.ts";
import type { DailyUsage, UsageReader } from "./usage-service.ts";
import { NO_USAGE } from "./usage-service.ts";
import type {
  FinalizeOutcome,
  FinalizeResult,
  ReservationResult,
  ReserveInput,
  ReserveOutcome,
  SlotStore,
} from "./slot-reservation.ts";

/** Shape returned by both SQL functions. */
interface SlotRow {
  outcome: string;
  used_today: number;
  reserved_today: number;
}

export function createServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set to reach the usage tables.",
    );
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

/** `returns table (...)` arrives as an array; we always want the single row. */
function firstRow(data: unknown): SlotRow | null {
  if (Array.isArray(data)) return (data[0] as SlotRow) ?? null;
  return (data as SlotRow) ?? null;
}

const RESERVE_OUTCOMES: readonly string[] = [
  "reserved",
  "duplicate",
  "limit_reached",
];

const FINALIZE_OUTCOMES: readonly string[] = [
  "succeeded",
  "released",
  "not_reserved",
];

export function createSupabaseUsageReader(client: SupabaseClient): UsageReader {
  return async (userId: string, day: CairoDay): Promise<DailyUsage> => {
    const { data, error } = await client
      .from("analysis_usage_daily")
      .select("successful_count, reserved_count")
      .eq("user_id", userId)
      .eq("usage_date", day)
      .maybeSingle();

    if (error) throw error;
    // No row simply means the user has not analysed today.
    if (!data) return NO_USAGE;

    return {
      successfulCount: data.successful_count ?? 0,
      reservedCount: data.reserved_count ?? 0,
    };
  };
}

export function createSupabaseSlotStore(client: SupabaseClient): SlotStore {
  return {
    async reserve(input: ReserveInput): Promise<ReservationResult> {
      const { data, error } = await client.rpc("reserve_analysis_slot", {
        p_user_id: input.userId,
        p_usage_date: input.day,
        p_request_id: input.requestId,
        p_installation_hash: input.installationHash,
        p_daily_limit: input.dailyLimit,
        p_ttl_seconds: input.ttlSeconds,
      });

      if (error) throw error;

      const row = firstRow(data);
      if (row === null || !RESERVE_OUTCOMES.includes(row.outcome)) {
        // Fail closed: an unreadable answer must not be treated as a slot.
        throw new Error("reserve_analysis_slot returned an unusable result");
      }

      return {
        outcome: row.outcome as ReserveOutcome,
        usedToday: row.used_today,
        reservedToday: row.reserved_today,
      };
    },

    async finalize(
      requestId: string,
      success: boolean,
      errorCode?: string,
    ): Promise<FinalizeResult> {
      const { data, error } = await client.rpc("finalize_analysis_slot", {
        p_request_id: requestId,
        p_success: success,
        p_error_code: errorCode ?? null,
      });

      if (error) throw error;

      const row = firstRow(data);
      if (row === null || !FINALIZE_OUTCOMES.includes(row.outcome)) {
        throw new Error("finalize_analysis_slot returned an unusable result");
      }

      return {
        outcome: row.outcome as FinalizeOutcome,
        usedToday: row.used_today,
        reservedToday: row.reserved_today,
      };
    },
  };
}
