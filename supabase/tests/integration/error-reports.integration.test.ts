/**
 * F27-T12 · `error_reports` against the real database.
 *
 * The constraints and the ceiling are the parts that cannot be tested with a
 * fake: a CHECK either refuses a row or it does not, and the per-user daily cap
 * is a count-and-insert that only means anything inside one statement. So each
 * test here writes through `record_error_report` exactly as the Edge Function
 * does, with the service role, and asserts what Postgres actually allowed.
 *
 * The three questions:
 *
 * 1. Does a report land, with every field intact?
 * 2. Does the ceiling stop a crash loop? (B3's lesson: an unbounded write path
 *    on a public project is a quota drain waiting to be found.)
 * 3. Can content get in through a column, past the API's allowlist? The checks
 *    are the second line of defence and are tested as such — prose, spaces, a
 *    stage that is not a stage, an impossible status.
 *
 * Needs a running stack plus SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and
 * SUPABASE_ANON_KEY. Skips when absent, so a bare `deno test` stays green.
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

function record(
  client: SupabaseClient,
  userId: string,
  overrides: Record<string, unknown> = {},
) {
  return client.rpc("record_error_report", {
    p_user_id: userId,
    p_error_code: "OCR",
    ...overrides,
  });
}

async function reportsFor(
  client: SupabaseClient,
  userId: string,
): Promise<Record<string, unknown>[]> {
  const { data, error } = await client
    .from("error_reports")
    .select("*")
    .eq("user_id", userId);
  assertEquals(error, null);
  return (data ?? []) as Record<string, unknown>[];
}

function daysAgo(days: number): string {
  const instant = new Date();
  instant.setUTCDate(instant.getUTCDate() - days);
  return instant.toISOString();
}

Deno.test({
  name: "[integration] a report is stored with every field it carried",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();
    const requestId = crypto.randomUUID();
    const sessionId = crypto.randomUUID();

    const { data, error } = await record(client, userId, {
      p_error_code: "ONLINE_OCR_UNAVAILABLE",
      p_stage: "ocr",
      p_result_status: "failure",
      p_request_id: requestId,
      p_analysis_session_id: sessionId,
      p_http_status: 502,
      p_duration_ms: 1200,
      p_app_version: "1.0.0",
      p_schema_version: "2.0",
    });

    assertEquals(error, null);
    assertEquals(data, "recorded");

    const rows = await reportsFor(client, userId);
    assertEquals(rows.length, 1);
    assertEquals(rows[0].error_code, "ONLINE_OCR_UNAVAILABLE");
    assertEquals(rows[0].stage, "ocr");
    assertEquals(rows[0].result_status, "failure");
    assertEquals(rows[0].request_id, requestId);
    assertEquals(rows[0].analysis_session_id, sessionId);
    assertEquals(rows[0].http_status, 502);
    assertEquals(rows[0].duration_ms, 1200);
    assertEquals(rows[0].app_version, "1.0.0");
    assertEquals(rows[0].schema_version, "2.0");
    assert(rows[0].reported_at !== null, "reported_at defaults to now()");
  },
});

Deno.test({
  name: "[integration] a crash report with nothing but a code is stored",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    const { data, error } = await record(client, userId, {
      p_error_code: "UNCAUGHT_FLUTTER_ERROR",
    });

    assertEquals(error, null);
    assertEquals(data, "recorded");

    const rows = await reportsFor(client, userId);
    assertEquals(rows[0].error_code, "UNCAUGHT_FLUTTER_ERROR");
    assertEquals(rows[0].stage, null);
    assertEquals(rows[0].request_id, null);
  },
});

Deno.test({
  name: "[integration] the per-user ceiling stops a crash loop",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    // A low cap, passed in: the policy default is 100, and proving the
    // mechanism must not mean writing a hundred rows.
    for (let i = 0; i < 3; i++) {
      const { data } = await record(client, userId, { p_daily_cap: 3 });
      assertEquals(data, "recorded", `report ${i + 1} of 3`);
    }

    const { data: refused, error } = await record(client, userId, {
      p_daily_cap: 3,
    });
    assertEquals(error, null);
    assertEquals(refused, "rate_limited");
    assertEquals(
      (await reportsFor(client, userId)).length,
      3,
      "the refused report left no row",
    );
  },
});

Deno.test({
  name: "[integration] the ceiling is per user, not global",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const noisy = await newUser();
    const quiet = await newUser();

    await record(client, noisy, { p_daily_cap: 1 });
    const { data: noisyAgain } = await record(client, noisy, { p_daily_cap: 1 });
    assertEquals(noisyAgain, "rate_limited");

    // One user in a crash loop must not silence everybody else's reports.
    const { data: other } = await record(client, quiet, { p_daily_cap: 1 });
    assertEquals(other, "recorded");
  },
});

Deno.test({
  name: "[integration] the column checks refuse anything that is not a code",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    // The API's allowlist is the first line; these are the second. Prose and
    // anything with a space cannot be stored at all, so even a direct
    // service-role insert cannot park document content in this column.
    for (
      const code of [
        "فاتورة الكهرباء 850 جنيه",
        "Null pointer at line 42",
        "ocr",
        "OCR FAILED",
        "A",
      ]
    ) {
      const { error } = await record(client, userId, { p_error_code: code });
      assert(error !== null, `${JSON.stringify(code)} must be refused`);
    }

    assertEquals(await reportsFor(client, userId), []);
  },
});

Deno.test({
  name: "[integration] the column checks refuse an impossible envelope",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    const rejected: Record<string, unknown>[] = [
      { p_stage: "upload" },
      { p_result_status: "failed" },
      { p_http_status: 99 },
      { p_http_status: 600 },
      { p_duration_ms: -1 },
      { p_app_version: "1.0" },
      { p_schema_version: "two" },
    ];

    for (const overrides of rejected) {
      const { error } = await record(client, userId, overrides);
      assert(error !== null, `${JSON.stringify(overrides)} must be refused`);
    }

    assertEquals(await reportsFor(client, userId), []);
  },
});

Deno.test({
  name: "[integration] the purge takes old reports and leaves recent ones",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    // Inserted directly, because a backdated row is the one thing
    // `record_error_report` cannot produce — it always stamps `now()` — and
    // the table has no UPDATE grant to rewrite it with (see the next test).
    const { error: insertError } = await client.from("error_reports").insert({
      user_id: userId,
      error_code: "OCR",
      reported_at: daysAgo(100),
    });
    assertEquals(insertError, null);

    const recentUser = await newUser();
    await record(client, recentUser);

    const { data, error } = await client.rpc("purge_old_error_reports", {});
    assertEquals(error, null);
    assert(
      typeof data === "number" && data >= 1,
      "the purge must report the rows it deleted",
    );

    assertEquals(
      await reportsFor(client, userId),
      [],
      "a 100-day-old report must be gone",
    );
    assertEquals(
      (await reportsFor(client, recentUser)).length,
      1,
      "a report from today must survive the 90-day policy",
    );
  },
});

Deno.test({
  name: "[integration] a stored report cannot be rewritten",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    await record(client, userId, { p_error_code: "LOCAL_DATABASE" });

    // Append-only by privilege, not by convention: the migration grants
    // select, insert and delete, and deliberately not update. Monitoring data
    // that can be edited after the fact is not evidence of anything — and the
    // service role is the most privileged thing that ever reaches this table.
    const { error } = await client
      .from("error_reports")
      .update({ error_code: "OCR" })
      .eq("user_id", userId);

    assert(error !== null, "UPDATE must be refused even for service_role");
    assertEquals((await reportsFor(client, userId))[0].error_code, "LOCAL_DATABASE");
  },
});

Deno.test({
  name: "[integration] deleting a user cascades their reports away",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const userId = await newUser();

    await record(client, userId);
    assertEquals((await reportsFor(client, userId)).length, 1);

    // T07's idle-user purge is what will do this in production; the point is
    // that it needs no companion cleanup for this new table.
    const { error } = await client.rpc("purge_idle_anonymous_users", {
      p_idle_for: "00:00:00",
    });
    assertEquals(error, null);

    assertEquals(await reportsFor(client, userId), []);
  },
});

Deno.test({
  name: "[integration] the retention report now lists all three jobs",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();

    const { data, error } = await client.rpc("retention_jobs_report");
    assertEquals(error, null);

    const jobs = (data ?? []) as { jobname: string; active: boolean }[];
    const byName = new Map(jobs.map((job) => [job.jobname, job]));

    for (
      const name of [
        "purge-old-analysis-attempts",
        "purge-idle-anonymous-users",
        "purge-old-error-reports",
      ]
    ) {
      const job = byName.get(name);
      assert(job !== undefined, `${name} must be scheduled`);
      assertEquals(job.active, true, `${name} must be active`);
    }
  },
});

Deno.test({
  name: "[integration] the table is unreachable with the publishable key",
  ignore: skip,
  fn: async () => {
    // RLS on with no policies and no grants (§26). Reports are operational
    // data; no client may read them, including the one that filed them.
    const anon = createClient(supabaseUrl!, anonKey!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await anon.from("error_reports").select("id");

    assert(
      error !== null || (data ?? []).length === 0,
      "an anonymous client must not be able to read error reports",
    );
  },
});
