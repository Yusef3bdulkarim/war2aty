/**
 * F06-T08 · Loading runtime config from `app_runtime_config`.
 *
 * Split from the parsing so the rules stay testable without a database.
 *
 * The table is service-role read-only (F06-T02): a function consumes config
 * and can never rewrite its own limits.
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import { ApiError } from "../errors/api-error.ts";
import { parseRuntimeConfig, type RuntimeConfig, type RuntimeConfigRow } from "./runtime-config.ts";

/**
 * Reads every config key and assembles a {@link RuntimeConfig}.
 *
 * A failed READ throws rather than quietly falling back to defaults. Defaults
 * say `analysisEnabled: true`, so silently using them would make the kill
 * switch fail OPEN — the service would keep calling a paid AI provider during
 * precisely the incident someone was trying to stop. Failing here costs
 * nothing in practice: the same database is needed a moment later to reserve
 * a slot, so the request could not have succeeded anyway.
 *
 * Individual malformed rows are still tolerated — that fallback lives in
 * `parseRuntimeConfig`.
 */
export async function loadRuntimeConfig(
  client: SupabaseClient,
): Promise<RuntimeConfig> {
  const { data, error } = await client
    .from("app_runtime_config")
    .select("key, value");

  if (error) {
    // The provider message can quote connection details; it never reaches the
    // client, which only sees INTERNAL_ERROR.
    throw ApiError.internalError();
  }

  return parseRuntimeConfig((data ?? []) as RuntimeConfigRow[]);
}
