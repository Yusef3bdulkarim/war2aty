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
import { createImageAnalysisPipeline } from "../_shared/analyze/image-analysis-pipeline.ts";
import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { azureOptionsFromEnv } from "../_shared/azure/azure-config.ts";
import { createAzureDocumentIntelligenceClient } from "../_shared/azure/azure-client.ts";
import { loadRuntimeConfig } from "../_shared/config/supabase-runtime-config.ts";
import {
  googleDocumentAiOptionsFromEnv,
  isGoogleDocumentAiConfigured,
} from "../_shared/google/google-config.ts";
import { createGoogleDocumentAiClient } from "../_shared/google/google-client.ts";
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
      // Azure/Google env vars are read here, not at module load, so a
      // deployment that never sees an image request (azureOcrEnabled dark)
      // never has to have them configured — same contract as
      // `azureOptionsFromEnv`/`googleDocumentAiOptionsFromEnv` document.
      //
      // Google is optional: an org policy may block service-account key
      // creation, and the pipeline works fine with Azure alone — unchecked
      // fields simply stay flagged for user review.
      createImagePipeline: (timeoutSeconds) =>
        createImageAnalysisPipeline({
          azureClient: createAzureDocumentIntelligenceClient({
            ...azureOptionsFromEnv(),
            timeoutSeconds,
          }),
          googleClient: isGoogleDocumentAiConfigured()
            ? createGoogleDocumentAiClient({
                ...googleDocumentAiOptionsFromEnv(),
                timeoutSeconds,
              })
            : null,
        }),
      hashInstallation: installationHasherFromEnv(),
      now: () => new Date(),
    }),
  }),
);
