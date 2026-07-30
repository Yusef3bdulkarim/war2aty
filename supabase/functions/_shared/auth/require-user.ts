/**
 * F06-T03 · Authorization gate for the Edge Functions.
 *
 * Every protected endpoint runs this BEFORE any request parsing, quota check,
 * or AI call, so an unauthenticated caller can never reach logic that costs
 * money or touches the database.
 *
 * The platform already enforces `verify_jwt = true` (config.toml) for
 * analyze-document and get-usage, so a bad token is normally rejected at the
 * gateway. This is the second layer: it re-verifies and, crucially, extracts
 * the `userId` that the quota tables are keyed on. Never trust an id supplied
 * in the request body — only the one proven by the token.
 *
 * PRIVACY: the token itself is never logged, returned, or attached to an error.
 */

/** The only identity the app has: an anonymous Supabase user (§6). */
export interface AuthenticatedUser {
  readonly id: string;
  /** True for Anonymous Auth users, which is every user in the MVP. */
  readonly isAnonymous: boolean;
}

/**
 * Why authorization failed.
 *
 * `missing_token` and `invalid_token` are the caller's fault and map to
 * 401 UNAUTHORIZED. `verification_failed` means the auth service itself was
 * unreachable — a server problem that must map to 500, not 401, so a Supabase
 * outage is never reported to the user as "you are not signed in".
 */
export type AuthFailureReason =
  | "missing_token"
  | "invalid_token"
  | "verification_failed";

export type RequireUserResult =
  | { readonly ok: true; readonly user: AuthenticatedUser }
  | { readonly ok: false; readonly reason: AuthFailureReason };

/**
 * Resolves a bearer token to a user, or `null` when the token is invalid or
 * expired. Throws only when verification could not be performed at all.
 *
 * Injected so the endpoints can be tested without a live auth service.
 */
export type TokenVerifier = (token: string) => Promise<AuthenticatedUser | null>;

const BEARER_SCHEME = "bearer";

/**
 * Pulls the credential out of an `Authorization` header.
 *
 * Returns `null` for anything that is not a non-empty Bearer credential. Per
 * RFC 7235 the scheme is case-insensitive, so `bearer`/`BEARER` are accepted.
 */
export function extractBearerToken(
  authorizationHeader: string | null,
): string | null {
  if (authorizationHeader === null) return null;

  const trimmed = authorizationHeader.trim();
  const separatorIndex = trimmed.indexOf(" ");
  if (separatorIndex === -1) return null;

  const scheme = trimmed.slice(0, separatorIndex);
  if (scheme.toLowerCase() !== BEARER_SCHEME) return null;

  const token = trimmed.slice(separatorIndex + 1).trim();
  // A token containing whitespace is malformed, not a credential with spaces.
  if (token.length === 0 || /\s/.test(token)) return null;

  return token;
}

/**
 * Authenticates a request. Never throws — every outcome is a value the caller
 * maps to an HTTP response.
 */
export async function requireUser(
  request: Request,
  verifyToken: TokenVerifier,
): Promise<RequireUserResult> {
  const token = extractBearerToken(request.headers.get("Authorization"));
  if (token === null) {
    return { ok: false, reason: "missing_token" };
  }

  let user: AuthenticatedUser | null;
  try {
    user = await verifyToken(token);
  } catch {
    // Swallow the cause deliberately: it can carry the token or provider
    // internals, and neither belongs in a log or a response body.
    return { ok: false, reason: "verification_failed" };
  }

  if (user === null) {
    return { ok: false, reason: "invalid_token" };
  }

  return { ok: true, user };
}

/** Whether a failure is the caller's fault (401) or ours (500). */
export function isClientAuthFailure(reason: AuthFailureReason): boolean {
  return reason === "missing_token" || reason === "invalid_token";
}
