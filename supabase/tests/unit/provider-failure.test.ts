/**
 * F20-T03 · Tests for the provider-failure taxonomy (failure matrix §1).
 *
 * The expected tables are typed `Record<ProviderFailureKind, …>`, so adding a
 * kind without deciding its fallback eligibility and wire mapping is a compile
 * error here rather than a silent default.
 */

import { assert, assertEquals, assertInstanceOf } from "jsr:@std/assert@1";

import {
  analysisApiErrorFor,
  isFallbackEligible,
  PROVIDER_FAILURE_KINDS,
  ProviderFailure,
  providerFailureForStatus,
  type ProviderFailureKind,
} from "../../functions/_shared/ai/provider-failure.ts";
import { toApiError } from "../../functions/_shared/errors/api-error.ts";
import type { ErrorCode } from "../../functions/_shared/errors/error-codes.ts";

// ── fallback eligibility (rows A1–A7) ─────────────────────────────────────

const ELIGIBLE: Record<ProviderFailureKind, boolean> = {
  rate_limited: true,
  upstream_unavailable: true,
  timeout: true,
  network: true,
  invalid_output: true,
  auth: false,
  bad_request: false,
};

Deno.test("PROVIDER_FAILURE_KINDS lists every kind exactly once", () => {
  assertEquals(
    [...PROVIDER_FAILURE_KINDS].sort(),
    (Object.keys(ELIGIBLE) as ProviderFailureKind[]).sort(),
  );
  assertEquals(new Set(PROVIDER_FAILURE_KINDS).size, PROVIDER_FAILURE_KINDS.length);
});

for (const kind of PROVIDER_FAILURE_KINDS) {
  Deno.test(`${kind} is ${ELIGIBLE[kind] ? "" : "NOT "}fallback-eligible`, () => {
    assertEquals(isFallbackEligible(kind), ELIGIBLE[kind]);
  });
}

// ── status classification ─────────────────────────────────────────────────

const STATUS_CASES: ReadonlyArray<readonly [number, ProviderFailureKind]> = [
  [429, "rate_limited"],
  [401, "auth"],
  [403, "auth"],
  [408, "upstream_unavailable"],
  [500, "upstream_unavailable"],
  [502, "upstream_unavailable"],
  [503, "upstream_unavailable"],
  [504, "upstream_unavailable"],
  // Anthropic-style "overloaded"; some OpenAI-compatible gateways use it too.
  [529, "upstream_unavailable"],
  [400, "bad_request"],
  [404, "bad_request"],
  [413, "bad_request"],
  [422, "bad_request"],
];

for (const [status, kind] of STATUS_CASES) {
  Deno.test(`HTTP ${status} is classified as ${kind}`, () => {
    assertEquals(providerFailureForStatus(status).kind, kind);
  });
}

Deno.test("an unexpected 4xx fails closed as bad_request, never eligible", () => {
  const failure = providerFailureForStatus(418);

  assertEquals(failure.kind, "bad_request");
  assertEquals(isFallbackEligible(failure.kind), false);
});

Deno.test("an unfollowed redirect fails closed as bad_request", () => {
  // A 3xx from an API endpoint means a wrong base URL: our fault, not theirs.
  assertEquals(providerFailureForStatus(302).kind, "bad_request");
});

// ── wire mapping for the analysis endpoint (rows A1–A7) ───────────────────

const ANALYSIS_WIRE: Record<ProviderFailureKind, ErrorCode> = {
  rate_limited: "AI_RATE_LIMITED",
  timeout: "TIMEOUT",
  upstream_unavailable: "ANALYSIS_FAILED",
  network: "ANALYSIS_FAILED",
  invalid_output: "ANALYSIS_FAILED",
  auth: "INTERNAL_ERROR",
  bad_request: "INTERNAL_ERROR",
};

for (const kind of PROVIDER_FAILURE_KINDS) {
  Deno.test(`${kind} reaches the app as ${ANALYSIS_WIRE[kind]}`, () => {
    assertEquals(analysisApiErrorFor(new ProviderFailure(kind)).code, ANALYSIS_WIRE[kind]);
  });
}

Deno.test("the mapped wire body never names the failure kind or a provider", () => {
  for (const kind of PROVIDER_FAILURE_KINDS) {
    const body = JSON.stringify(analysisApiErrorFor(new ProviderFailure(kind)).toBody());

    assert(!body.includes(kind), `wire body leaked the kind "${kind}"`);
    for (const name of ["groq", "mistral", "gemini"]) {
      assert(!body.toLowerCase().includes(name), `wire body named ${name}`);
    }
  }
});

// ── the class itself ──────────────────────────────────────────────────────

Deno.test("ProviderFailure is an Error carrying its kind and a fixed message", () => {
  const failure = new ProviderFailure("network");

  assertInstanceOf(failure, Error);
  assertEquals(failure.name, "ProviderFailure");
  assertEquals(failure.kind, "network");
  assertEquals(failure.message, "AI provider failure: network.");
});

Deno.test("an unmapped ProviderFailure is never serialised as itself", () => {
  // The fail-safe for a caller that forgets to map: the endpoint boundary
  // turns it into a generic 500, never a body carrying the kind.
  const apiError = toApiError(new ProviderFailure("rate_limited"));

  assertEquals(apiError.code, "INTERNAL_ERROR");
  assertEquals(apiError.status, 500);
});
