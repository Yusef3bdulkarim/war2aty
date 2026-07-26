/**
 * F06-T08 · Loading runtime config from the real table.
 *
 * The unit tests cover the parsing rules; what only a live database can show
 * is that the seeded rows actually round-trip through JSONB and PostgREST as
 * the parser expects — JSON `null`, numbers and strings all arrive with the
 * types it assumes.
 *
 * Needs SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (the table is service-role
 * only). Skips otherwise.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import { loadRuntimeConfig } from "../../functions/_shared/config/supabase-runtime-config.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

const ready = Boolean(supabaseUrl && serviceRoleKey && anonKey) &&
  await reachable();
const skip = !ready;

async function reachable(): Promise<boolean> {
  try {
    const response = await fetch(`${supabaseUrl}/auth/v1/health`, {
      headers: { apikey: anonKey! },
      signal: AbortSignal.timeout(2000),
    });
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}

function serviceClient(): SupabaseClient {
  return createClient(supabaseUrl!, serviceRoleKey!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

Deno.test({
  name: "[integration] the seeded table loads as the documented defaults",
  ignore: skip,
  fn: async () => {
    const config = await loadRuntimeConfig(serviceClient());

    assertEquals(config.analysisEnabled, true);
    assertEquals(config.dailyLimit, 3);
    assertEquals(config.maxOcrCharacters, 12000);
    assertEquals(config.minimumAppVersion, "1.0.0");
    assertEquals(config.schemaVersion, "1.0");
    // JSONB null must arrive as "operating normally", not the string "null".
    assertEquals(config.maintenanceMessage, null);
  },
});

Deno.test({
  name: "[integration] a failed read throws instead of failing the kill switch open",
  ignore: skip,
  fn: async () => {
    // anon cannot read the table, which stands in for any read failure. The
    // defaults say analysisEnabled: true, so silently falling back to them
    // would keep calling a paid provider during the incident someone was
    // trying to stop.
    const anonClient = createClient(supabaseUrl!, anonKey!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const thrown = await assertRejects(() => loadRuntimeConfig(anonClient));

    assert(thrown instanceof ApiError);
    assertEquals((thrown as ApiError).code, "INTERNAL_ERROR");
  },
});

Deno.test({
  name: "[integration] a function cannot raise its own daily cap",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();

    assertEquals((await loadRuntimeConfig(client)).dailyLimit, 3);

    // The table is granted SELECT only to service_role (F06-T02), so a bug or
    // a compromised function cannot lift the limit it is subject to.
    const { error } = await client
      .from("app_runtime_config")
      .update({ value: 999 })
      .eq("key", "daily_limit");

    assert(error !== null, "a function must not be able to raise its own cap");
    assertEquals(
      (await loadRuntimeConfig(client)).dailyLimit,
      3,
      "the cap must be unchanged",
    );
  },
});
