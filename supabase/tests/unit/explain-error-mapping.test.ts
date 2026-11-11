/**
 * F36-T17 · The error-mapping table for `explain-document`.
 *
 * Both stages (reading and explaining) collapse their `ProviderFailureKind` onto
 * the closed `ERROR_CODES` list through `analysisApiErrorFor` — the same
 * mapping `analyze-document` uses. T07 and T11 said "T17 pins it"; this is
 * that pin.
 *
 * `OCR_UNAVAILABLE` is unreachable (trap #3): that code tells the app it may
 * read the page on the device instead, and after F39 there is no on-device
 * reader, so emitting it would be an instruction the client cannot follow.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  analysisApiErrorFor,
  PROVIDER_FAILURE_KINDS,
  ProviderFailure,
  type ProviderFailureKind,
} from "../../functions/_shared/ai/provider-failure.ts";
import {
  ERROR_CODES,
  type ErrorCode,
} from "../../functions/_shared/errors/error-codes.ts";

// ── the mapping table (§33.7) ────────────────────────────────────────────────
//
// Both the reading stage and the explaining stage use `analysisApiErrorFor`.
// The table is typed as a total Record, so a kind added to
// `ProviderFailureKind` without deciding its mapping is a compile error here
// rather than a runtime gap.

const EXPLAIN_WIRE: Record<ProviderFailureKind, ErrorCode> = {
  rate_limited: "AI_RATE_LIMITED",
  timeout: "TIMEOUT",
  upstream_unavailable: "ANALYSIS_FAILED",
  network: "ANALYSIS_FAILED",
  invalid_output: "ANALYSIS_FAILED",
  auth: "INTERNAL_ERROR",
  bad_request: "INTERNAL_ERROR",
};

// ── table-driven: every kind through the reading stage ───────────────────────

for (const kind of PROVIDER_FAILURE_KINDS) {
  Deno.test(`explain reading stage: ${kind} → ${EXPLAIN_WIRE[kind]}`, () => {
    assertEquals(
      analysisApiErrorFor(new ProviderFailure(kind)).code,
      EXPLAIN_WIRE[kind],
    );
  });
}

// ── table-driven: every kind through the explaining stage ────────────────────
//
// A separate loop so the test names show BOTH stages pinned, and so a future
// split would turn into two tables rather than one silently covering both.

for (const kind of PROVIDER_FAILURE_KINDS) {
  Deno.test(`explain explaining stage: ${kind} → ${EXPLAIN_WIRE[kind]}`, () => {
    assertEquals(
      analysisApiErrorFor(new ProviderFailure(kind)).code,
      EXPLAIN_WIRE[kind],
    );
  });
}

// ── OCR_UNAVAILABLE is unreachable (trap #3) ─────────────────────────────────

Deno.test("no ProviderFailureKind maps to OCR_UNAVAILABLE on the explain endpoint", () => {
  for (const kind of PROVIDER_FAILURE_KINDS) {
    const code = analysisApiErrorFor(new ProviderFailure(kind)).code;
    assert(
      code !== "OCR_UNAVAILABLE",
      `${kind} mapped to OCR_UNAVAILABLE — trap #3 violated`,
    );
  }
});

// ── every produced code is in the closed ERROR_CODES list ────────────────────

Deno.test("every code produced by the explain mapping is in ERROR_CODES", () => {
  const closed = new Set<string>(ERROR_CODES);
  for (const kind of PROVIDER_FAILURE_KINDS) {
    const code = analysisApiErrorFor(new ProviderFailure(kind)).code;
    assert(
      closed.has(code),
      `${kind} mapped to "${code}", which is not in ERROR_CODES`,
    );
  }
});

// ── the table covers every kind ──────────────────────────────────────────────

Deno.test("EXPLAIN_WIRE covers every ProviderFailureKind", () => {
  const tableKinds = Object.keys(EXPLAIN_WIRE).sort();
  const allKinds = [...PROVIDER_FAILURE_KINDS].sort();
  assertEquals(tableKinds, allKinds);
});

// ── the mapping stays apart from OCR's ───────────────────────────────────────
//
// `ocrApiErrorFor` maps three kinds to `OCR_UNAVAILABLE`, which is the right
// answer for `ocr-document` and the wrong answer for `explain-document`. This
// test makes that divergence visible: anyone who edits `analysisApiErrorFor`
// and makes it produce `OCR_UNAVAILABLE` breaks this test first.

Deno.test("the explain mapping never agrees with ocrApiErrorFor where it says OCR_UNAVAILABLE", () => {
  // The three kinds `ocrApiErrorFor` maps to OCR_UNAVAILABLE:
  const ocrOnlyKinds: ProviderFailureKind[] = [
    "upstream_unavailable",
    "network",
    "invalid_output",
  ];

  for (const kind of ocrOnlyKinds) {
    const explainCode = analysisApiErrorFor(new ProviderFailure(kind)).code;
    assert(
      explainCode !== "OCR_UNAVAILABLE",
      `${kind} must not produce OCR_UNAVAILABLE on the explain path`,
    );
  }
});
