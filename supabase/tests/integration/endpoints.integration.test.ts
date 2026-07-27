/**
 * F06-T13 · Integration tests for the three endpoints.
 *
 * These hit the REAL functions on a running local stack, which is the only way
 * to prove the things fakes cannot: that `verify_jwt` is actually enforced by
 * the gateway, that `config.toml` routes the functions at all, and that the
 * service role really can reach the usage tables from inside a function.
 *
 * Requires `supabase start` plus SUPABASE_URL / SUPABASE_ANON_KEY. When either
 * is missing, or the stack is down, they skip rather than fail, so a bare
 * `deno test` stays green and deterministic:
 *
 *   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=<anon key> \
 *     deno test --allow-net --allow-env supabase/tests
 *
 * ── Why no live Groq call by default ─────────────────────────────────────
 * A real analysis is billed, non-deterministic, and reserved against an
 * 8000-token minute. The one test that performs one is gated behind
 * `RUN_LIVE_ANALYSIS=1` and asserts only shape, never content.
 *
 * No key is hard-coded here — nothing key-shaped belongs in git.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { INSTALLATION_ID, OCR_TEXT, validRequestBody } from "../fixtures/analyze-fixtures.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const runLiveAnalysis = Deno.env.get("RUN_LIVE_ANALYSIS") === "1";

async function isStackReachable(): Promise<boolean> {
  if (!supabaseUrl || !supabaseAnonKey) return false;
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/health`, {
      signal: AbortSignal.timeout(5000),
    });
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}

const skip = !(await isStackReachable());

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

function endpoint(name: string): string {
  return `${supabaseUrl}/functions/v1/${name}`;
}

/** A fresh session id per call, so no test collides with another's quota row. */
function freshRequestBody(overrides: Record<string, unknown> = {}) {
  return validRequestBody({
    session_id: crypto.randomUUID(),
    installation_id: INSTALLATION_ID,
    ...overrides,
  });
}

async function post(
  token: string | null,
  body: unknown,
  headers: Record<string, string> = {},
): Promise<Response> {
  return await fetch(endpoint("analyze-document"), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token === null ? {} : { Authorization: `Bearer ${token}`, apikey: supabaseAnonKey! }),
      ...headers,
    },
    body: JSON.stringify(body),
  });
}

// ── health ────────────────────────────────────────────────────────────────

Deno.test({
  name: "[integration] health answers without a token",
  ignore: skip,
  fn: async () => {
    const response = await fetch(endpoint("health"));

    assertEquals(response.status, 200);
    assertEquals((await response.json()).status, "ok");
    // Correlation works even on the unauthenticated probe.
    assert(response.headers.get("x-request-id") !== null);
  },
});

Deno.test({
  name: "[integration] health refuses a method it does not serve",
  ignore: skip,
  fn: async () => {
    const response = await fetch(endpoint("health"), { method: "POST" });

    assertEquals(response.status, 400);
    assertEquals((await response.json()).error.code, "INVALID_REQUEST");
  },
});

Deno.test({
  name: "[integration] a preflight is answered for the browser case",
  ignore: skip,
  fn: async () => {
    const response = await fetch(endpoint("health"), { method: "OPTIONS" });
    await response.body?.cancel();

    assertEquals(response.status, 204);
    assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  },
});

// ── auth is enforced by the platform, not just by our code ────────────────

Deno.test({
  name: "[integration] analyze-document rejects a call with no token",
  ignore: skip,
  fn: async () => {
    const response = await post(null, freshRequestBody());
    await response.body?.cancel();

    // The gateway's `verify_jwt = true` fires before our handler; either way
    // the caller must never reach logic that costs money.
    assertEquals(response.status, 401);
  },
});

Deno.test({
  name: "[integration] get-usage rejects a call with no token",
  ignore: skip,
  fn: async () => {
    const response = await fetch(endpoint("get-usage"));
    await response.body?.cancel();

    assertEquals(response.status, 401);
  },
});

// ── get-usage against the real tables ─────────────────────────────────────

Deno.test({
  name: "[integration] get-usage reports a fresh quota for a new anonymous user",
  ignore: skip,
  fn: async () => {
    const token = await mintAnonymousToken();

    const response = await fetch(endpoint("get-usage"), {
      headers: { Authorization: `Bearer ${token}`, apikey: supabaseAnonKey! },
    });

    assertEquals(response.status, 200);
    const body = await response.json();

    // Proves the service role really can read `analysis_usage_daily` from
    // inside a function — RLS is on with zero policies, so a missing grant
    // would surface exactly here (§26).
    assertEquals(body.used_today, 0);
    assertEquals(body.remaining_today, body.daily_limit);
    assert(/^\d{4}-\d{2}-\d{2}$/.test(body.usage_date));
    assert(typeof body.analysis_enabled === "boolean");
  },
});

// ── request validation over the wire ──────────────────────────────────────

Deno.test({
  name: "[integration] an unknown schema version is refused",
  ignore: skip,
  fn: async () => {
    const token = await mintAnonymousToken();
    const response = await post(token, freshRequestBody({ schema_version: "9.9" }));

    assertEquals(response.status, 400);
    assertEquals((await response.json()).error.code, "UNSUPPORTED_SCHEMA");
  },
});

Deno.test({
  name: "[integration] empty ocr text is refused before any AI call",
  ignore: skip,
  fn: async () => {
    const token = await mintAnonymousToken();
    const response = await post(token, freshRequestBody({ ocr_text: "" }));

    assertEquals(response.status, 400);
    assertEquals((await response.json()).error.code, "INVALID_REQUEST");
  },
});

Deno.test({
  name: "[integration] a body carrying image data is refused",
  ignore: skip,
  fn: async () => {
    // The privacy tripwire, checked end to end: the paper never leaves the
    // phone, so nothing image-shaped may be accepted (§7).
    const token = await mintAnonymousToken();
    const response = await post(token, freshRequestBody({ image_base64: "iVBORw0KGgo=" }));

    assertEquals(response.status, 400);
    assertEquals((await response.json()).error.code, "INVALID_REQUEST");
  },
});

Deno.test({
  name: "[integration] the client's request id comes back on the response",
  ignore: skip,
  fn: async () => {
    const token = await mintAnonymousToken();
    const requestId = crypto.randomUUID();

    const response = await post(token, freshRequestBody({ ocr_text: "" }), {
      "x-request-id": requestId,
    });
    await response.body?.cancel();

    assertEquals(response.headers.get("x-request-id"), requestId);
  },
});

// ── one real analysis, opt-in ─────────────────────────────────────────────

Deno.test({
  name: "[integration][live] a real analysis returns a §30 body and counts one use",
  ignore: skip || !runLiveAnalysis,
  fn: async () => {
    const token = await mintAnonymousToken();

    const response = await post(token, freshRequestBody({ ocr_text: OCR_TEXT }));
    assertEquals(response.status, 200);

    const body = await response.json();
    // Shape only. The model's wording is not a contract and must never be
    // asserted; the fields are.
    assertEquals(body.schema_version, "1.0");
    assert(["success", "partial", "unsupported"].includes(body.status));
    assert(typeof body.document_type.title === "string");
    assert(Array.isArray(body.dates));
    assert(Array.isArray(body.amounts));

    const usage = await fetch(endpoint("get-usage"), {
      headers: { Authorization: `Bearer ${token}`, apikey: supabaseAnonKey! },
    });
    const quota = await usage.json();

    // An `unsupported` reading is not counted (§31 rule 6); anything else is.
    assertEquals(quota.used_today, body.status === "unsupported" ? 0 : 1);
  },
});
