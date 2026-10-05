/**
 * F27-T07 · Retention jobs against the real database.
 *
 * The two pg_cron jobs call `purge_old_analysis_attempts` and
 * `purge_idle_anonymous_users`, so the predicates are what these exercise —
 * a DELETE inlined into a cron string could not be tested at all. Each test
 * backdates rows it created itself and asserts both directions: the old row
 * goes, the recent one stays. Nothing here depends on the real 90-day and
 * 12-month windows having elapsed; the window is passed in, while the
 * scheduled jobs take the defaults that hold Q11's policy.
 *
 * Needs a running stack plus SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and
 * SUPABASE_ANON_KEY (these tables are service-role only). Skips when absent,
 * so a bare `deno test` stays green. Values come from `supabase status`.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

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

async function newUser(): Promise<string> {
  const response = await fetch(`${supabaseUrl}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: anonKey!, "Content-Type": "application/json" },
    body: "{}",
  });
  const session = await response.json();
  const payload = session.access_token.split(".")[1];
  const padded = payload.replace(/-/g, "+").replace(/_/g, "/");
  const claims = JSON.parse(
    atob(padded + "=".repeat((4 - padded.length % 4) % 4)),
  );
  return claims.sub as string;
}

async function addAttempt(
  client: SupabaseClient,
  userId: string,
  requestId: string,
  createdAt: string,
): Promise<void> {
  const { error } = await client.from("analysis_attempts").insert({
    request_id: requestId,
    user_id: userId,
    usage_date: "2026-07-26",
    installation_hash: "retention-test",
    status: "succeeded",
    created_at: createdAt,
    expires_at: createdAt,
    // `analysis_attempts_completed_at_matches_status` requires a terminal
    // status to carry a completion time, so a fixture cannot leave it null.
    completed_at: createdAt,
  });
  assertEquals(error, null);
}

async function attemptExists(
  client: SupabaseClient,
  requestId: string,
): Promise<boolean> {
  const { data } = await client
    .from("analysis_attempts")
    .select("request_id")
    .eq("request_id", requestId)
    .maybeSingle();
  return data !== null;
}

Deno.test({
  name:
    "[integration] the attempts purge takes old rows and leaves recent ones",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();
    const old = crypto.randomUUID();
    const recent = crypto.randomUUID();

    // 100 days back is past the 90-day policy; 10 is well inside it.
    await addAttempt(client, userId, old, daysAgo(100));
    await addAttempt(client, userId, recent, daysAgo(10));

    const { data, error } = await client.rpc("purge_old_analysis_attempts", {});
    assertEquals(error, null);
    assert(
      typeof data === "number" && data >= 1,
      "the purge must report the rows it deleted",
    );

    assertEquals(
      await attemptExists(client, old),
      false,
      "a 100-day-old attempt must be gone",
    );
    assertEquals(
      await attemptExists(client, recent),
      true,
      "a 10-day-old attempt must survive the 90-day policy",
    );
  },
});

Deno.test({
  name: "[integration] the attempts purge honours the window it is given",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();
    const justNow = crypto.randomUUID();

    await addAttempt(client, userId, justNow, new Date().toISOString());

    // A zero window means "everything", which is how the first test's fixtures
    // would be swept up too — proving the interval is really the predicate and
    // not a hardcoded 90 days the parameter cannot reach.
    const { error } = await client.rpc("purge_old_analysis_attempts", {
      p_older_than: "00:00:00",
    });
    assertEquals(error, null);
    assertEquals(await attemptExists(client, justNow), false);
  },
});

Deno.test({
  name: "[integration] the idle-user purge spares a user who just signed in",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    const { data, error } = await client.rpc("purge_idle_anonymous_users", {});
    assertEquals(error, null);
    assert(typeof data === "number", "the purge must report a row count");

    // The policy is 12 months; a user created seconds ago must be untouched,
    // including the coalesce branch for a null last_sign_in_at.
    const { data: still } = await client.auth.admin.getUserById(userId);
    assert(still.user !== null, "a brand-new anonymous user must survive");
  },
});

Deno.test({
  name: "[integration] the idle-user purge cascades to attempts and usage",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();
    const attempt = crypto.randomUUID();

    await addAttempt(client, userId, attempt, daysAgo(1));
    const { error: usageError } = await client
      .from("analysis_usage_daily")
      .insert({
        user_id: userId,
        usage_date: "2026-07-26",
        successful_count: 1,
      });
    assertEquals(usageError, null);

    // A zero idle window deletes every anonymous user, this one included, which
    // is what lets the cascade be observed without waiting a year.
    const { error } = await client.rpc("purge_idle_anonymous_users", {
      p_idle_for: "00:00:00",
    });
    assertEquals(error, null);

    assertEquals(
      await attemptExists(client, attempt),
      false,
      "the deleted user's attempts must cascade away",
    );
    const { data: usage } = await client
      .from("analysis_usage_daily")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();
    assertEquals(
      usage,
      null,
      "the deleted user's usage rows must cascade away",
    );
  },
});

Deno.test({
  name: "[integration] both retention jobs are scheduled",
  ignore: skip,
  fn: async () => {
    // The functions existing is not the policy; the schedule is. Read through a
    // service-role RPC because the `cron` schema is not exposed to PostgREST.
    const client = serviceClient();
    const { data, error } = await client.rpc("retention_jobs_report", {});

    assertEquals(error, null);
    const names = (data as Array<{ jobname: string; schedule: string }>)
      .map((row) => row.jobname)
      .sort();
    assertEquals(names, [
      "purge-idle-anonymous-users",
      "purge-old-analysis-attempts",
    ]);
  },
});

function daysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}
