/**
 * F06-T03 · Integration tests for the authorization gate.
 *
 * These exercise the REAL Supabase-backed verifier against a running local
 * stack, which is the only way to prove the things a fake verifier cannot:
 * that signatures are actually checked, and that an unreachable auth service
 * is reported as a server fault rather than a 401.
 *
 * Requires `supabase start` plus SUPABASE_URL and SUPABASE_ANON_KEY in the
 * environment. When either is missing the tests skip instead of failing, so a
 * plain `deno test` stays green and deterministic without the stack:
 *
 *   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=<anon key> \
 *     deno test --allow-net --allow-env supabase/tests
 *
 * No key is hard-coded here — nothing key-shaped belongs in git.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { requireUser } from "../../functions/_shared/auth/require-user.ts";
import { createSupabaseTokenVerifier } from "../../functions/_shared/auth/supabase-token-verifier.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

const stackReachable = await isStackReachable();
const skip = !stackReachable;

async function isStackReachable(): Promise<boolean> {
  if (!supabaseUrl || !supabaseAnonKey) return false;
  try {
    const response = await fetch(`${supabaseUrl}/auth/v1/health`, {
      headers: { apikey: supabaseAnonKey },
      signal: AbortSignal.timeout(2000),
    });
    // Drain the body so Deno does not flag a leaked resource.
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}

/** Mints a real anonymous session exactly as the app does on first launch. */
async function mintAnonymousToken(): Promise<string> {
  const response = await fetch(`${supabaseUrl}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: supabaseAnonKey!, "Content-Type": "application/json" },
    body: "{}",
  });
  const session = await response.json();
  return session.access_token as string;
}

function requestWith(authorization?: string): Request {
  return new Request("https://example.test/functions/v1/analyze-document", {
    method: "POST",
    headers: authorization ? { Authorization: authorization } : {},
  });
}

Deno.test({
  name: "[integration] accepts a real anonymous JWT and extracts the user id",
  ignore: skip,
  fn: async () => {
    const token = await mintAnonymousToken();
    const result = await requireUser(
      requestWith(`Bearer ${token}`),
      createSupabaseTokenVerifier(),
    );

    assert(result.ok, "a freshly minted anonymous JWT must be accepted");
    assertEquals(result.user.isAnonymous, true);
    // The id must come from the token, never from the request body.
    assert(
      /^[0-9a-f-]{36}$/.test(result.user.id),
      `expected a uuid, got ${result.user.id}`,
    );
  },
});

Deno.test({
  name: "[integration] rejects a token that is not a JWT",
  ignore: skip,
  fn: async () => {
    const result = await requireUser(
      requestWith("Bearer not-a-jwt"),
      createSupabaseTokenVerifier(),
    );

    assert(!result.ok);
    assertEquals(result.reason, "invalid_token");
  },
});

Deno.test({
  name: "[integration] rejects a well-formed JWT with a forged signature",
  ignore: skip,
  fn: async () => {
    // Valid header/payload shape, far-future expiry, bogus signature. If this
    // were ever accepted, anyone could mint their own identity.
    const forged = [
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
      "eyJzdWIiOiIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDAiLCJyb2xlIjoiYXV0aGVudGljYXRlZCIsImV4cCI6NDA3MDkwODgwMH0",
      "ZmFrZXNpZ25hdHVyZQ",
    ].join(".");

    const result = await requireUser(
      requestWith(`Bearer ${forged}`),
      createSupabaseTokenVerifier(),
    );

    assert(!result.ok, "a forged signature must never authenticate");
    assertEquals(result.reason, "invalid_token");
  },
});

Deno.test({
  name: "[integration] reports a server fault, not 401, when auth is unreachable",
  ignore: skip,
  fn: async () => {
    const token = await mintAnonymousToken();

    const original = Deno.env.get("SUPABASE_URL")!;
    Deno.env.set("SUPABASE_URL", "http://127.0.0.1:1");
    let verifier;
    try {
      verifier = createSupabaseTokenVerifier();
    } finally {
      Deno.env.set("SUPABASE_URL", original);
    }

    const result = await requireUser(requestWith(`Bearer ${token}`), verifier);

    assert(!result.ok);
    // An outage must never be reported to the user as "you are not signed in".
    assertEquals(result.reason, "verification_failed");
  },
});
