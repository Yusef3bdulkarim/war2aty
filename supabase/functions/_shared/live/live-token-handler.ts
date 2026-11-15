/**
 * F37-T10 · The live-token handler.
 *
 * Authenticates the anonymous user, checks the two service gates, mints a
 * single-use ephemeral token from Google, and returns the WebSocket URL the
 * phone connects to. The sequence mirrors `get-usage` — cheap checks first,
 * the one outbound call last:
 *
 *   1. auth               — nobody unauthenticated may trigger a Google call
 *   2. runtime config      — one read; also the two gates below
 *   3. analysisEnabled     — the kill switch
 *   4. explainEnabled      — voice is part of the explain flow (D3)
 *   5. mint token          — the only outbound call, against Google's auth_tokens
 *
 * No slot is reserved and no daily limit is checked: the token is for READING
 * an explanation that `explain-document` already produced and charged. The
 * explain daily limit is enforced when the explanation is requested, not when
 * it is spoken.
 *
 * PRIVACY: the minted token appears only inside `ws_url` in the response
 * body. It is never logged, and the API key never leaves the server.
 */

import { ApiError, apiErrorForAuthFailure } from "../errors/api-error.ts";
import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import type { RuntimeConfig } from "../config/runtime-config.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { jsonResponse } from "../http/response.ts";
import { logEvent } from "../observability/log.ts";
import {
  type GeminiTokenOptions,
  type MintedToken,
  mintEphemeralToken,
} from "./gemini-token-client.ts";

export interface LiveTokenResponseBody {
  /** Full WebSocket URL the phone connects to, token included. */
  readonly ws_url: string;
  /** The model id the setup frame should carry (prefixed `models/`). */
  readonly model: string;
  /** When this token stops working, ISO-8601. */
  readonly expires_at: string;
}

export type TokenMinter = (
  options: GeminiTokenOptions,
) => Promise<
  | { readonly ok: true; readonly token: MintedToken }
  | {
    readonly ok: false;
    readonly reason: "rate_limited" | "not_available" | "internal";
  }
>;

export interface LiveTokenDependencies {
  readonly verifyToken: TokenVerifier;
  readonly loadConfig: () => Promise<RuntimeConfig>;
  readonly mintToken: TokenMinter;
  readonly geminiApiKey: string;
  readonly geminiModel: string;
  readonly geminiApiVersion: string;
}

export function createLiveTokenHandler(
  dependencies: LiveTokenDependencies,
): EndpointHandler {
  const {
    verifyToken,
    loadConfig,
    mintToken,
    geminiApiKey,
    geminiModel,
    geminiApiVersion,
  } = dependencies;

  return async ({ request, requestId }): Promise<Response> => {
    // 1. auth
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    // 2. runtime config
    const config = await loadConfig();

    // 3. kill switch
    if (!config.analysisEnabled) throw ApiError.analysisDisabled();

    // 4. explain gate — voice is part of the explain flow
    if (!config.explainEnabled) throw ApiError.analysisDisabled();

    // 5. mint
    const result = await mintToken({
      apiKey: geminiApiKey,
      model: geminiModel,
      apiVersion: geminiApiVersion,
    });

    if (!result.ok) {
      logEvent("live-token.mint_failed", {
        request_id: requestId,
        reason: result.reason,
      });

      switch (result.reason) {
        case "rate_limited":
          throw ApiError.aiRateLimited();
        case "not_available":
          throw ApiError.internalError();
        case "internal":
          throw ApiError.internalError();
      }
    }

    const body: LiveTokenResponseBody = {
      ws_url: result.token.wsUrl,
      model: result.token.model,
      expires_at: result.token.expiresAt,
    };

    logEvent("live-token.minted", {
      request_id: requestId,
      model: geminiModel,
    });

    return jsonResponse(body, { requestId });
  };
}
