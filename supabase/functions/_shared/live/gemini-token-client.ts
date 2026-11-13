/**
 * F37-T10 · Mints a single-use ephemeral token from Google's `auth_tokens` API.
 *
 * The token lets the phone open a Live WebSocket directly to Google — audio
 * goes Google → phone with zero Supabase egress (Path A in the transport fork).
 * The API key stays in Supabase Secrets and never reaches the device.
 *
 * ── What the spike settled ──────────────────────────────────────────────────
 * The minimal body (`uses`, `expireTime`, `newSessionExpireTime`) is what
 * F36-T02's spike probes first, and it alone answers whether the free tier
 * mints tokens at all. Constraint fields are probed separately by T01 and
 * added here only if one is accepted — an unconstrained single-use token that
 * expires in minutes is still safe.
 *
 * ── What T01 may change ─────────────────────────────────────────────────────
 * If ephemeral tokens are unavailable on the free tier, Path B1 (relay) takes
 * over and this file is the one that disappears. The handler's shape does not
 * change — the response still carries `ws_url` and `model`, only the URL
 * points to our relay instead of Google.
 *
 * PRIVACY: the minted token is returned to the caller inside `ws_url` and
 * never logged. The API key is read from the environment and never leaves
 * this function.
 */

const REST_BASE = "https://generativelanguage.googleapis.com";
const WS_BASE = "wss://generativelanguage.googleapis.com/ws";

/** How long the token is valid once minted. */
const TOKEN_TTL_MINUTES = 30;

/** How long after minting a new session may be started with this token. */
const SESSION_WINDOW_MINUTES = 2;

export interface GeminiTokenOptions {
  /** The Gemini API key, from Supabase Secrets. */
  readonly apiKey: string;
  /** API version for the `auth_tokens` endpoint. Default `v1beta`. */
  readonly apiVersion?: string;
  /** Gemini Live model id WITHOUT the `models/` prefix. */
  readonly model: string;
}

export interface MintedToken {
  /** Full WebSocket URL the phone connects to, token included. */
  readonly wsUrl: string;
  /** The model id the setup frame should carry (prefixed `models/`). */
  readonly model: string;
  /** When this token stops working, ISO-8601. */
  readonly expiresAt: string;
}

export type MintResult =
  | { readonly ok: true; readonly token: MintedToken }
  | { readonly ok: false; readonly reason: MintFailureReason };

export type MintFailureReason =
  | "rate_limited"
  | "not_available"
  | "internal";

/**
 * Mints a single-use ephemeral token.
 *
 * Returns `ok: false` with a classified reason so the handler can pick the
 * right §31 error code without inspecting HTTP bodies.
 */
export async function mintEphemeralToken(
  options: GeminiTokenOptions,
): Promise<MintResult> {
  const { apiKey, model, apiVersion = "v1beta" } = options;

  const now = Date.now();
  const expireTime = new Date(now + TOKEN_TTL_MINUTES * 60_000).toISOString();
  const newSessionExpireTime = new Date(
    now + SESSION_WINDOW_MINUTES * 60_000,
  ).toISOString();

  let response: Response;
  try {
    response = await fetch(`${REST_BASE}/${apiVersion}/auth_tokens`, {
      method: "POST",
      headers: {
        "x-goog-api-key": apiKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        uses: 1,
        expireTime,
        newSessionExpireTime,
      }),
    });
  } catch {
    return { ok: false, reason: "internal" };
  }

  if (response.status === 429) {
    return { ok: false, reason: "rate_limited" };
  }

  if (!response.ok) {
    return { ok: false, reason: "not_available" };
  }

  let body: { name?: string };
  try {
    body = (await response.json()) as { name?: string };
  } catch {
    return { ok: false, reason: "internal" };
  }

  const token = body.name;
  if (!token) {
    return { ok: false, reason: "not_available" };
  }

  // Ephemeral tokens are only accepted on the CONSTRAINED endpoint. The
  // unconstrained one takes an API key and answers a token with
  // `1008 Permission denied`; the constrained one answers a key with
  // `1007 Missing or malformed auth token`. Verified both ways, T01.
  const wsUrl =
    `${WS_BASE}/google.ai.generativelanguage.${apiVersion}.GenerativeService.BidiGenerateContentConstrained` +
    `?access_token=${encodeURIComponent(token)}`;

  return {
    ok: true,
    token: {
      wsUrl,
      model: `models/${model}`,
      expiresAt: expireTime,
    },
  };
}
