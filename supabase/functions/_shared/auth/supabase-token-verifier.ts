/**
 * F06-T03 · The production {@link TokenVerifier}, backed by Supabase Auth.
 *
 * Kept apart from `require-user.ts` so the gate's logic stays free of the
 * supabase-js dependency and can be unit-tested without a network or a running
 * auth service.
 *
 * We ask GoTrue rather than verifying the signature locally: it also catches
 * users that were deleted or banned since the token was issued, and it keeps
 * working if the project moves from the shared JWT secret to asymmetric keys.
 */

import { createClient } from "npm:@supabase/supabase-js@2";

import type { AuthenticatedUser, TokenVerifier } from "./require-user.ts";

/**
 * Builds a verifier from the environment the Edge Runtime injects.
 *
 * Uses the ANON key, never the service-role key: this call only needs to read
 * the identity a token already proves, so it should carry no other authority.
 *
 * @throws if the runtime environment is missing — a deploy/config fault we want
 * to surface loudly at startup rather than as a puzzling 401 per request.
 */
export function createSupabaseTokenVerifier(): TokenVerifier {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_ANON_KEY must be set for token verification.",
    );
  }

  const client = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  return async (token: string): Promise<AuthenticatedUser | null> => {
    const { data, error } = await client.auth.getUser(token);

    if (error) {
      // 4xx means the token is genuinely bad — expired, revoked, malformed.
      // Anything else (5xx, network) means we could not decide, so we throw and
      // let the caller answer 500 rather than mislabel it as unauthorized.
      const status = error.status ?? 0;
      if (status >= 400 && status < 500) return null;
      throw error;
    }

    const user = data.user;
    if (!user) return null;

    return {
      id: user.id,
      isAnonymous: user.is_anonymous ?? false,
    };
  };
}
