/**
 * F37-T10 · `POST /functions/v1/live-token` — a voice session endpoint.
 *
 * Wiring only. The handler lives in `live-token-handler.ts` so it can be
 * tested without a stack, a network, or a Google bill. Credentials are read
 * at startup so a missing env var fails loudly instead of becoming a puzzling
 * 500 on every call.
 */

import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { loadRuntimeConfig } from "../_shared/config/supabase-runtime-config.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { createServiceRoleClient } from "../_shared/usage/supabase-usage-store.ts";
import { mintEphemeralToken } from "../_shared/live/gemini-token-client.ts";
import { createLiveTokenHandler } from "../_shared/live/live-token-handler.ts";

const serviceClient = createServiceRoleClient();

function requireEnv(key: string): string {
  const value = Deno.env.get(key)?.trim();
  if (!value) throw new Error(`Missing required env var: ${key}`);
  return value;
}

const geminiApiKey = requireEnv("GEMINI_API_KEY");
const geminiModel = Deno.env.get("GEMINI_LIVE_MODEL")?.trim() ||
  "gemini-2.5-flash-native-audio-latest";
const geminiApiVersion = Deno.env.get("GEMINI_LIVE_API_VERSION")?.trim() ||
  "v1beta";

Deno.serve(
  createEndpoint({
    name: "live-token",
    method: "POST",
    handle: createLiveTokenHandler({
      verifyToken: createSupabaseTokenVerifier(),
      loadConfig: () => loadRuntimeConfig(serviceClient),
      mintToken: mintEphemeralToken,
      geminiApiKey,
      geminiModel,
      geminiApiVersion,
    }),
  }),
);
