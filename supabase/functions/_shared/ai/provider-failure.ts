/**
 * F20-T03 · `ProviderFailure` — why an upstream AI provider did not give us a
 * usable answer.
 *
 * F18 carried this as one boolean on `ApiError` (`providerFault`), and the
 * fallback chain failed over whenever it was set. A boolean cannot say *which*
 * failure happened, so it could not express the rule F20 needs (failure matrix
 * §1): fall back on transient and output failures, and NEVER on a bad key, a
 * wrong model name, or our own malformed request. Retrying those against a
 * second provider only hides a deploy fault that someone has to fix.
 *
 * So transports throw a `ProviderFailure` carrying a closed `kind`. Callers
 * decide from the kind alone:
 * - the analysis chain asks {@link isFallbackEligible};
 * - the endpoint turns whatever reaches it into a §31 error with
 *   {@link analysisApiErrorFor}.
 *
 * `ProviderFailure` never reaches the wire itself. `toApiError` would turn an
 * unmapped one into a generic INTERNAL_ERROR, which is why every caller maps it
 * explicitly.
 *
 * Config faults (a missing `*_API_KEY` or `*_MODEL`) are NOT a kind here. They
 * are thrown as plain `Error`s when the client is built, before any request
 * exists, and surface as INTERNAL_ERROR like any other bug (matrix row A8).
 *
 * PRIVACY (§7, §51): the message is a fixed string naming the kind only. It is
 * never built from a provider's response body, which can echo the prompt, and
 * the prompt is the user's document.
 */

import { ApiError } from "../errors/api-error.ts";

/**
 * Every way a provider call can fail, and nothing else. See the task file's §1
 * for the matrix that each kind maps to.
 */
export type ProviderFailureKind =
  /** HTTP 429: the provider's quota or rate limit. The common case on free tiers. */
  | "rate_limited"
  /** HTTP 5xx (including 529 "overloaded") or 408: the provider is unwell. */
  | "upstream_unavailable"
  /** Our own time budget ran out before the provider answered. */
  | "timeout"
  /** The request never completed: DNS, TLS, a dropped connection. */
  | "network"
  /**
   * The provider answered, but not with something we can use: an empty body,
   * a truncated completion, non-JSON, the wrong shape, or output that fails
   * semantic validation.
   */
  | "invalid_output"
  /** HTTP 401/403: a revoked or wrong key. A config fault, not a transient one. */
  | "auth"
  /** Any other HTTP 4xx: our request or model name is wrong. A programmer fault. */
  | "bad_request";

export const PROVIDER_FAILURE_KINDS: readonly ProviderFailureKind[] = [
  "rate_limited",
  "upstream_unavailable",
  "timeout",
  "network",
  "invalid_output",
  "auth",
  "bad_request",
];

export class ProviderFailure extends Error {
  readonly kind: ProviderFailureKind;

  constructor(kind: ProviderFailureKind) {
    super(`AI provider failure: ${kind}.`);
    this.name = "ProviderFailure";
    this.kind = kind;
  }
}

/**
 * The closed allowlist of kinds worth asking a second provider about.
 *
 * A set rather than a switch that defaults to `true`: a kind added later stays
 * ineligible until someone deliberately puts it here.
 */
const FALLBACK_ELIGIBLE: ReadonlySet<ProviderFailureKind> = new Set<ProviderFailureKind>([
  "rate_limited",
  "upstream_unavailable",
  "timeout",
  "network",
  "invalid_output",
]);

/**
 * Whether this kind of failure may be retried against the fallback provider.
 *
 * This answers the question about the KIND only. The chain still has to check
 * that enough of the request's deadline remains (§2), so `timeout` is eligible
 * here even though a timed-out primary usually leaves too little time for a
 * second call.
 */
export function isFallbackEligible(kind: ProviderFailureKind): boolean {
  return FALLBACK_ELIGIBLE.has(kind);
}

/**
 * Classifies a non-2xx provider status.
 *
 * Only statuses that clearly mean "try again later" count as transient.
 * Everything else in the 4xx range, including codes we never expect, is
 * `bad_request`. Unknown statuses therefore fail closed, meaning no fallback,
 * because a surprise status is far more likely to be our own mistake than a
 * transient provider problem.
 */
export function providerFailureForStatus(status: number): ProviderFailure {
  if (status === 429) return new ProviderFailure("rate_limited");
  if (status === 401 || status === 403) return new ProviderFailure("auth");
  if (status === 408 || status >= 500) return new ProviderFailure("upstream_unavailable");
  return new ProviderFailure("bad_request");
}

/**
 * The §31 error an analysis request answers with when this failure is the
 * final one (matrix rows A1–A7).
 *
 * The code tells the app what it can do about the failure. It never says which
 * provider failed, or that there was more than one.
 * - `auth` and `bad_request` are OUR faults, so they surface as INTERNAL_ERROR.
 *   An unusable answer surfaces as ANALYSIS_FAILED instead.
 */
export function analysisApiErrorFor(failure: ProviderFailure): ApiError {
  switch (failure.kind) {
    case "rate_limited":
      return ApiError.aiRateLimited();
    case "timeout":
      return ApiError.timeout();
    case "upstream_unavailable":
    case "network":
    case "invalid_output":
      return ApiError.analysisFailed();
    case "auth":
    case "bad_request":
      return ApiError.internalError();
  }
}

/**
 * The §31 error `ocr-document` answers with when the online reader failed
 * (matrix rows O3–O6, F20-T13).
 *
 * The code decides whether the app may read the page on the device instead:
 * `AI_RATE_LIMITED`, `TIMEOUT` and `OCR_UNAVAILABLE` are on its closed
 * fallback allowlist, `INTERNAL_ERROR` is not. So an outage, a dropped
 * connection and an unusable reading become `OCR_UNAVAILABLE`, while a bad key
 * or a bad request stays `INTERNAL_ERROR`: a deploy fault must be seen and
 * fixed, not quietly papered over by the phone.
 */
export function ocrApiErrorFor(failure: ProviderFailure): ApiError {
  switch (failure.kind) {
    case "rate_limited":
      return ApiError.aiRateLimited();
    case "timeout":
      return ApiError.timeout();
    case "upstream_unavailable":
    case "network":
    case "invalid_output":
      return ApiError.ocrUnavailable();
    case "auth":
    case "bad_request":
      return ApiError.internalError();
  }
}
