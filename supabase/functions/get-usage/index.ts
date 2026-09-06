/**
 * F06-T13 · `GET /functions/v1/get-usage` — today's quota.
 *
 * Wiring only. The clients are built once per worker rather than per request:
 * under `policy = "oneshot"` a worker serves one request anyway, and a missing
 * environment variable throws here — at startup, loudly — instead of becoming
 * a puzzling 500 on every call.
 */

import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { loadRuntimeConfig } from "../_shared/config/supabase-runtime-config.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import {
  createServiceRoleClient,
  createSupabaseUsageReader,
} from "../_shared/usage/supabase-usage-store.ts";
import { createUsageHandler } from "../_shared/usage/usage-handler.ts";

const serviceClient = createServiceRoleClient();

Deno.serve(
  createEndpoint({
    name: "get-usage",
    method: "GET",
    handle: createUsageHandler({
      verifyToken: createSupabaseTokenVerifier(),
      loadConfig: () => loadRuntimeConfig(serviceClient),
      readUsage: createSupabaseUsageReader(serviceClient),
      now: () => new Date(),
    }),
  }),
);
