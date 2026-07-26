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
    });

    assert(error !== null, "anon must not be able to grant itself slots");
  },
});
