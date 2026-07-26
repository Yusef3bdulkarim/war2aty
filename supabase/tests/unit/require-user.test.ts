/**
 * F06-T03 · Tests for the authorization gate.
 *
 * The verifier is injected, so these are deterministic and need no network,
 * no running stack, and no real JWT.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  type AuthenticatedUser,
  extractBearerToken,
  isClientAuthFailure,
  requireUser,
  type TokenVerifier,
} from "../../functions/_shared/auth/require-user.ts";

const testUser: AuthenticatedUser = {
  id: "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  isAnonymous: true,
};

/** Accepts one specific token and rejects everything else. */
function verifierAccepting(validToken: string): TokenVerifier {
  return (token) => Promise.resolve(token === validToken ? testUser : null);
}

function request(headers: Record<string, string> = {}): Request {
  return new Request("https://example.test/functions/v1/analyze-document", {
    method: "POST",
    headers,
  });
}

// ── extractBearerToken ────────────────────────────────────────────────────

Deno.test("extractBearerToken reads the credential from a well-formed header", () => {
  assertEquals(extractBearerToken("Bearer abc.def.ghi"), "abc.def.ghi");
});

Deno.test("extractBearerToken accepts a lowercase scheme (RFC 7235)", () => {
  assertEquals(extractBearerToken("bearer abc.def.ghi"), "abc.def.ghi");
});

Deno.test("extractBearerToken tolerates surrounding whitespace", () => {
  assertEquals(extractBearerToken("  Bearer   abc.def.ghi  "), "abc.def.ghi");
});

Deno.test("extractBearerToken returns null when the header is absent", () => {
  assertEquals(extractBearerToken(null), null);
});

Deno.test("extractBearerToken rejects a non-Bearer scheme", () => {
  assertEquals(extractBearerToken("Basic dXNlcjpwYXNz"), null);
});

Deno.test("extractBearerToken rejects a bare token with no scheme", () => {
  assertEquals(extractBearerToken("abc.def.ghi"), null);
});

Deno.test("extractBearerToken rejects an empty credential", () => {
  assertEquals(extractBearerToken("Bearer "), null);
});

Deno.test("extractBearerToken rejects a credential containing whitespace", () => {
  assertEquals(extractBearerToken("Bearer abc def"), null);
});

// ── requireUser ───────────────────────────────────────────────────────────

Deno.test("requireUser resolves the user for a valid token", async () => {
  const result = await requireUser(
    request({ Authorization: "Bearer good-token" }),
    verifierAccepting("good-token"),
  );

  assert(result.ok);
  assertEquals(result.user.id, testUser.id);
  assertEquals(result.user.isAnonymous, true);
});

Deno.test("requireUser reports missing_token when the header is absent", async () => {
  const result = await requireUser(request(), verifierAccepting("good-token"));

  assert(!result.ok);
  assertEquals(result.reason, "missing_token");
});

Deno.test("requireUser reports missing_token when the header is malformed", async () => {
  const result = await requireUser(
    request({ Authorization: "Basic dXNlcjpwYXNz" }),
    verifierAccepting("good-token"),
  );

  assert(!result.ok);
  assertEquals(result.reason, "missing_token");
});

Deno.test("requireUser reports invalid_token when the verifier rejects it", async () => {
  const result = await requireUser(
    request({ Authorization: "Bearer expired-token" }),
    verifierAccepting("good-token"),
  );

  assert(!result.ok);
  assertEquals(result.reason, "invalid_token");
});

Deno.test("requireUser reports verification_failed when the auth service throws", async () => {
  const unreachable: TokenVerifier = () => Promise.reject(new Error("auth service unreachable"));

  const result = await requireUser(
    request({ Authorization: "Bearer good-token" }),
    unreachable,
  );

  assert(!result.ok);
  assertEquals(result.reason, "verification_failed");
});

Deno.test("requireUser does not call the verifier when no token is present", async () => {
  let called = false;
  const spy: TokenVerifier = (token) => {
    called = true;
    return Promise.resolve(token === "good-token" ? testUser : null);
  };

  await requireUser(request(), spy);

  assertEquals(called, false);
});

Deno.test("requireUser surfaces a non-anonymous user faithfully", async () => {
  const permanent: TokenVerifier = () => Promise.resolve({ id: testUser.id, isAnonymous: false });

  const result = await requireUser(
    request({ Authorization: "Bearer good-token" }),
    permanent,
  );

  assert(result.ok);
  assertEquals(result.user.isAnonymous, false);
});

// ── isClientAuthFailure ───────────────────────────────────────────────────

Deno.test("isClientAuthFailure blames the caller for missing and invalid tokens", () => {
  assertEquals(isClientAuthFailure("missing_token"), true);
  assertEquals(isClientAuthFailure("invalid_token"), true);
});

Deno.test("isClientAuthFailure blames the server when verification could not run", () => {
  assertEquals(isClientAuthFailure("verification_failed"), false);
});
