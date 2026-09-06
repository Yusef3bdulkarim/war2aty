/**
 * F06-T07 · Race-safety tests against the real database.
 *
 * Sequential calls prove nothing about concurrency. These fire genuinely
 * parallel RPCs through PostgREST — separate connections, separate
 * transactions — which is the only way to show the quota actually holds when a
 * user taps three times before the first analysis finishes.
 *
 * Needs a running stack plus SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
 * (the usage tables are unreachable without the service role). Skips when
 * absent, so a bare `deno test` stays green. Values come from
 * `supabase status`; nothing key-shaped is committed here.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  createSupabaseSlotStore,
  createSupabaseUsageReader,
} from "../../functions/_shared/usage/supabase-usage-store.ts";
import type { ReserveInput } from "../../functions/_shared/usage/slot-reservation.ts";

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

/** A fresh anonymous user, so each test starts from an empty quota. */
async function newUser(): Promise<string> {
  const response = await fetch(`${supabaseUrl}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: anonKey!, "Content-Type": "application/json" },
    body: "{}",
  });
  const session = await response.json();
  const payload = session.access_token.split(".")[1];
  const padded = payload.replace(/-/g, "+").replace(/_/g, "/");
  const claims = JSON.parse(atob(padded + "=".repeat((4 - padded.length % 4) % 4)));
  return claims.sub as string;
}

const DAY = "2026-07-26";

function input(userId: string, requestId: string, dailyLimit = 3): ReserveInput {
  return {
    userId,
    day: DAY,
    requestId,
    installationHash: "test-hash",
    dailyLimit,
    globalDailyCallCap: null,
    ttlSeconds: 60,
  };
}

Deno.test({
  name: "[integration] concurrent reservations never exceed the daily limit",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const userId = await newUser();

    // Ten simultaneous requests against a limit of three. A read-then-write
    // implementation would admit most of them.
    const attempts = Array.from(
      { length: 10 },
      () => store.reserve(input(userId, crypto.randomUUID(), 3)),
    );
    const results = await Promise.all(attempts);

    const reserved = results.filter((r) => r.outcome === "reserved").length;
    const refused = results.filter((r) => r.outcome === "limit_reached").length;

    assertEquals(reserved, 3, "exactly three slots may be granted");
    assertEquals(refused, 7);

    // The counter must agree with what was handed out.
    const usage = await createSupabaseUsageReader(client)(userId, DAY);
    assertEquals(usage.reservedCount, 3);
    assertEquals(usage.successfulCount, 0);
  },
});

Deno.test({
  name: "[integration] concurrent retries of one request id take a single slot",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const userId = await newUser();
    const requestId = crypto.randomUUID();

    // The same id five times at once — a flaky network retrying.
    const results = await Promise.all(
      Array.from({ length: 5 }, () => store.reserve(input(userId, requestId))),
    );

    assertEquals(results.filter((r) => r.outcome === "reserved").length, 1);
    assertEquals(results.filter((r) => r.outcome === "duplicate").length, 4);

    const usage = await createSupabaseUsageReader(client)(userId, DAY);
    assertEquals(usage.reservedCount, 1);
  },
});

Deno.test({
  name: "[integration] a failed analysis returns the slot to the user",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const read = createSupabaseUsageReader(client);
    const userId = await newUser();
    const requestId = crypto.randomUUID();

    await store.reserve(input(userId, requestId));
    const finalized = await store.finalize(requestId, false, "TIMEOUT");

    assertEquals(finalized.outcome, "released");

    const usage = await read(userId, DAY);
    assertEquals(usage.successfulCount, 0, "a failure must not be charged");
    assertEquals(usage.reservedCount, 0, "the slot must be handed back");
  },
});

Deno.test({
  name: "[integration] a successful analysis is counted once, not twice",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const read = createSupabaseUsageReader(client);
    const userId = await newUser();
    const requestId = crypto.randomUUID();

    await store.reserve(input(userId, requestId));
    assertEquals((await store.finalize(requestId, true)).outcome, "succeeded");
    // A duplicate finalize (timeout racing the real answer) must be inert.
    assertEquals((await store.finalize(requestId, true)).outcome, "not_reserved");

    const usage = await read(userId, DAY);
    assertEquals(usage.successfulCount, 1);
    assertEquals(usage.reservedCount, 0);
  },
});

Deno.test({
  name: "[integration] concurrent finalizes of one slot count it once",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const read = createSupabaseUsageReader(client);
    const userId = await newUser();
    const requestId = crypto.randomUUID();

    await store.reserve(input(userId, requestId));
    const results = await Promise.all(
      Array.from({ length: 5 }, () => store.finalize(requestId, true)),
    );

    assertEquals(results.filter((r) => r.outcome === "succeeded").length, 1);
    assertEquals(results.filter((r) => r.outcome === "not_reserved").length, 4);

    const usage = await read(userId, DAY);
    assertEquals(usage.successfulCount, 1, "must not be double-counted");
  },
});

Deno.test({
  name: "[integration] an expired reservation is reclaimed, not stranded",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const read = createSupabaseUsageReader(client);
    const userId = await newUser();

    // A one-second slot, left to lapse: the caller crashed.
    await store.reserve({
      ...input(userId, crypto.randomUUID()),
      ttlSeconds: 1,
    });
    assertEquals((await read(userId, DAY)).reservedCount, 1);

    await new Promise((resolve) => setTimeout(resolve, 1200));

    // The next reserve sweeps first, so the abandoned slot comes back rather
    // than costing the user an analysis until midnight.
    const next = await store.reserve(input(userId, crypto.randomUUID()));

    assertEquals(next.outcome, "reserved");
    assertEquals((await read(userId, DAY)).reservedCount, 1);
  },
});

Deno.test({
  name: "[integration] the quota is per user, not global",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const [first, second] = [await newUser(), await newUser()];

    await Promise.all(
      Array.from({ length: 3 }, () => store.reserve(input(first, crypto.randomUUID()))),
    );

    // The second user's quota must be untouched by the first exhausting theirs.
    const result = await store.reserve(input(second, crypto.randomUUID()));
    assertEquals(result.outcome, "reserved");
  },
});

// ── the global capacity breaker (F13-T02) ─────────────────────────────────
//
// Each of these owns its own `usage_date`. global_analysis_usage_daily is keyed
// on the day ALONE, so two tests sharing one would read each other's counters —
// and the row is cleared up front so a re-run starts from zero instead of
// inheriting the previous run's total.

interface GlobalUsage {
  readonly successful: number;
  readonly reserved: number;
}

async function globalUsage(
  client: SupabaseClient,
  day: string,
): Promise<GlobalUsage> {
  const { data, error } = await client
    .from("global_analysis_usage_daily")
    .select("successful_count, reserved_count")
    .eq("usage_date", day)
    .maybeSingle();

  if (error) throw error;

  // No row is the correct reading of "nothing has been counted today".
  return {
    successful: data?.successful_count ?? 0,
    reserved: data?.reserved_count ?? 0,
  };
}

/**
 * Zeroes a day's counters.
 *
 * An UPDATE rather than a DELETE on purpose: the service role has SELECT,
 * INSERT and UPDATE on this table and deliberately no DELETE, and widening a
 * production grant to make a test tidier would be the wrong trade. Matching no
 * row is success — {@link globalUsage} already reads absence as zero.
 */
async function resetGlobalDay(client: SupabaseClient, day: string): Promise<void> {
  const { error } = await client
    .from("global_analysis_usage_daily")
    .update({ successful_count: 0, reserved_count: 0 })
    .eq("usage_date", day);

  if (error) throw error;
}

/** A reservation on its own day, with the breaker set to `cap`. */
function capped(
  userId: string,
  requestId: string,
  day: string,
  cap: number | null,
  dailyLimit = 100,
): ReserveInput {
  return {
    ...input(userId, requestId, dailyLimit),
    day,
    globalDailyCallCap: cap,
  };
}

Deno.test({
  name: "[integration] concurrent reservations never exceed the global cap",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const day = "2026-07-20";
    await resetGlobalDay(client, day);
    const userId = await newUser();

    // The per-user limit is set high enough to be irrelevant, so the breaker is
    // the only thing that can refuse any of these. Ten at once against a cap of
    // three: a read-then-check implementation would admit most of them.
    const results = await Promise.all(
      Array.from(
        { length: 10 },
        () => store.reserve(capped(userId, crypto.randomUUID(), day, 3)),
      ),
    );

    assertEquals(
      results.filter((r) => r.outcome === "reserved").length,
      3,
      "exactly three calls may be granted",
    );
    assertEquals(
      results.filter((r) => r.outcome === "global_capacity_reached").length,
      7,
    );

    assertEquals((await globalUsage(client, day)).reserved, 3);

    // The refused seven each took a per-user slot before the breaker judged
    // them, and must have rolled it back. Leaking those would spend the user's
    // own quota on analyses that never ran.
    const usage = await createSupabaseUsageReader(client)(userId, day);
    assertEquals(usage.reservedCount, 3, "rolled-back slots must not be held");
  },
});

Deno.test({
  name: "[integration] the global cap counts across users, unlike the daily quota",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const day = "2026-07-21";
    await resetGlobalDay(client, day);

    // The abuse this exists to stop: fresh anonymous installs, each with an
    // untouched personal quota, drawing on one shared budget.
    const outcomes: string[] = [];
    for (const _ of [0, 1, 2]) {
      const result = await store.reserve(
        capped(await newUser(), crypto.randomUUID(), day, 2),
      );
      outcomes.push(result.outcome);
    }

    assertEquals(outcomes, ["reserved", "reserved", "global_capacity_reached"]);
  },
});

Deno.test({
  name: "[integration] a failed analysis returns the global slot too",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const day = "2026-07-22";
    await resetGlobalDay(client, day);
    const userId = await newUser();
    const requestId = crypto.randomUUID();

    await store.reserve(capped(userId, requestId, day, 1));
    assertEquals((await globalUsage(client, day)).reserved, 1);

    await store.finalize(requestId, false, "TIMEOUT");

    const after = await globalUsage(client, day);
    assertEquals(after.reserved, 0, "the global slot must be handed back");
    assertEquals(after.successful, 0, "a failure must not be charged globally");

    // At a cap of one, the next call only fits if that release was real.
    const next = await store.reserve(capped(userId, crypto.randomUUID(), day, 1));
    assertEquals(next.outcome, "reserved");
  },
});

Deno.test({
  name: "[integration] a success is counted globally exactly once",
  ignore: skip,
  fn: async () => {
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const day = "2026-07-23";
    await resetGlobalDay(client, day);
    const requestId = crypto.randomUUID();

    await store.reserve(capped(await newUser(), requestId, day, 5));
    assertEquals((await store.finalize(requestId, true)).outcome, "succeeded");
    // A duplicate finalize must be inert here too, or the day's spend would be
    // overstated and the breaker would trip early.
    assertEquals((await store.finalize(requestId, true)).outcome, "not_reserved");

    const after = await globalUsage(client, day);
    assertEquals(after.successful, 1);
    assertEquals(after.reserved, 0);
  },
});

Deno.test({
  name: "[integration] an attempt reserved before a cap existed leaves the global counter alone",
  ignore: skip,
  fn: async () => {
    // Why analysis_attempts.counted_globally exists. If an operator turns the
    // breaker on while a request is in flight, that request's finalize must not
    // decrement a global row its reserve never incremented — which would drift
    // the day's total below reality and hand out capacity that was spent.
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const day = "2026-07-24";
    await resetGlobalDay(client, day);

    // Someone else's counted call puts the day's total at one.
    const counted = crypto.randomUUID();
    await store.reserve(capped(await newUser(), counted, day, 10));
    await store.finalize(counted, true);
    assertEquals((await globalUsage(client, day)).successful, 1);

    // This one reserved with the breaker off, then settles.
    const uncounted = crypto.randomUUID();
    await store.reserve(capped(await newUser(), uncounted, day, null));
    await store.finalize(uncounted, true);

    const after = await globalUsage(client, day);
    assertEquals(after.successful, 1, "an uncounted attempt must not be added");
    assertEquals(after.reserved, 0, "nor may it decrement below reality");
  },
});

Deno.test({
  name: "[integration] an expired reservation releases the global slot it held",
  ignore: skip,
  fn: async () => {
    // The stranded-capacity failure mode: nothing but a reserve ever sweeps, so
    // if an abandoned global slot were not reclaimed here it would be held
    // against every user until Cairo midnight.
    const client = serviceClient();
    const store = createSupabaseSlotStore(client);
    const day = "2026-07-25";
    await resetGlobalDay(client, day);

    // A one-second slot from a user who never comes back: the caller crashed.
    const abandoned = await newUser();
    await store.reserve({
      ...capped(abandoned, crypto.randomUUID(), day, 1),
      ttlSeconds: 1,
    });
    assertEquals((await globalUsage(client, day)).reserved, 1);

    await new Promise((resolve) => setTimeout(resolve, 1200));

    // A DIFFERENT user, because that is the case a per-user sweep would miss.
    // At a cap of one this only fits if the sweep crossed the user boundary.
    const next = await store.reserve(
      capped(await newUser(), crypto.randomUUID(), day, 1),
    );

    assertEquals(next.outcome, "reserved");
    assertEquals((await globalUsage(client, day)).reserved, 1);
  },
});

Deno.test({
  name: "[integration] anon cannot call the reservation RPC",
  ignore: skip,
  fn: async () => {
    // EXECUTE defaults to PUBLIC, which would expose these as PostgREST RPC.
    const anonClient = createClient(supabaseUrl!, anonKey!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error } = await anonClient.rpc("reserve_analysis_slot", {
      p_user_id: await newUser(),
      p_usage_date: DAY,
      p_request_id: crypto.randomUUID(),
      p_installation_hash: "x",
      p_daily_limit: 999,
      p_ttl_seconds: 60,
      // The full current signature on purpose: with an argument missing this
      // would fail as "function not found" and pass for the wrong reason,
      // proving nothing about who may execute it.
      p_global_daily_cap: null,
    });

    assert(error !== null, "anon must not be able to grant itself slots");
  },
});
