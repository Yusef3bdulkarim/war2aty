/**
 * F06-T13 · `POST /functions/v1/analyze-document` — the analysis endpoint.
 *
 * Wiring only; the sequence lives in `analyze-handler.ts` and every rule lives
 * a layer below that. Keeping this file free of logic is what lets the whole
 * flow be tested with fakes, without Docker, a network, or a Groq bill.
 *
 * The Groq client is built per request because its timeout comes from runtime
 * config, which an operator can change without a redeploy. Everything else is
 * built once per worker so a missing environment variable fails at startup.
 */

import { createAnalyzeHandler } from "../_shared/analyze/analyze-handler.ts";
import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { loadRuntimeConfig } from "../_shared/config/supabase-runtime-config.ts";
import { createGroqClient, groqOptionsFromEnv } from "../_shared/groq/groq-client.ts";
import { createGroqAnalysisProvider } from "../_shared/groq/groq-provider.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { installationHasherFromEnv } from "../_shared/usage/installation-hash.ts";
import {
  createServiceRoleClient,
  createSupabaseSlotStore,
} from "../_shared/usage/supabase-usage-store.ts";

const serviceClient = createServiceRoleClient();

Deno.serve(
  createEndpoint({
    name: "analyze-document",
    method: "POST",
    handle: createAnalyzeHandler({
      verifyToken: createSupabaseTokenVerifier(),
      loadConfig: () => loadRuntimeConfig(serviceClient),
      slots: createSupabaseSlotStore(serviceClient),
      createAnalyser: (timeoutSeconds) =>
        createGroqAnalysisProvider({
          client: createGroqClient(groqOptionsFromEnv(timeoutSeconds)),
        }),
      hashInstallation: installationHasherFromEnv(),
      now: () => new Date(),
    }),
  }),
);
