/**
 * F06-T13 · `POST /functions/v1/analyze-document` — the analysis endpoint.
 *
 * Wiring only; the sequence lives in `analyze-handler.ts` and every rule lives
 * a layer below that. Keeping this file free of logic is what lets the whole
 * flow be tested with fakes, without Docker, a network, or a Groq bill.
 *
 * The analysis chain is built per request because its time budget comes from
 * runtime config, which an operator can change without a redeploy. Everything else is
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
import {
  type ChatClientOptions,
  createChatClient,
} from "../_shared/ai/openai-compatible-client.ts";
import { GROQ_REASONING_EFFORT, groqOptionsFromEnv } from "../_shared/ai/groq-config.ts";
import { mistralOptionsFromEnv } from "../_shared/ai/mistral-config.ts";
import { chainTimingFromEnv } from "../_shared/ai/chain-timing.ts";
import {
  type AnalysisProviderOptions,
  createAnalysisProvider,
} from "../_shared/ai/analysis-provider.ts";
import { createFallbackAnalysisProvider } from "../_shared/ai/fallback-provider.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { installationHasherFromEnv } from "../_shared/usage/installation-hash.ts";
import {
  createServiceRoleClient,
  createSupabaseSlotStore,
} from "../_shared/usage/supabase-usage-store.ts";

const serviceClient = createServiceRoleClient();

/**
 * One leg of the analysis chain, bound to credentials. The credentials are
 * read once, eagerly, by the caller. Its time budget arrives per call, as the
 * signal the chain cuts from the request's deadline (F20-T10).
 */
function legFor(
  options: ChatClientOptions,
  reasoningEffort?: AnalysisProviderOptions["reasoningEffort"],
) {
  return createAnalysisProvider({ client: createChatClient(options), reasoningEffort });
}

/**
 * Builds the analysis chain for one request.
 *
 * Credentials are read HERE, eagerly, and the handler calls this before
 * reserving a slot, so a missing or blank key is a loud deploy fault that costs
 * the user nothing (matrix row A8).
 *
 * Mistral first, Groq on a fallback-eligible failure (F20-T11). Both are
 * required: a deployment missing either fails every analysis here, loudly,
 * rather than quietly running on one provider. Groq alone keeps its
 * `reasoning_effort`; Mistral is not a reasoning model and gets none.
 */
function createAnalysisChain(timeoutSeconds: number, requestId: string) {
  return createFallbackAnalysisProvider({
    primary: legFor(mistralOptionsFromEnv()),
    primaryName: "mistral",
    fallback: legFor(groqOptionsFromEnv(), GROQ_REASONING_EFFORT),
    fallbackName: "groq",
    totalSeconds: timeoutSeconds,
    ...chainTimingFromEnv(),
    requestId,
  });
}

Deno.serve(
  createEndpoint({
    name: "analyze-document",
    method: "POST",
    handle: createAnalyzeHandler({
      verifyToken: createSupabaseTokenVerifier(),
      loadConfig: () => loadRuntimeConfig(serviceClient),
      slots: createSupabaseSlotStore(serviceClient),
      createAnalyser: createAnalysisChain,
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
