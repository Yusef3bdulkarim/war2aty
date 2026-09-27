/**
 * F06-T13 · `POST /functions/v1/analyze-document` — the analysis endpoint.
 *
 * Wiring only; the sequence lives in `analyze-handler.ts` and every rule lives
 * a layer below that. Keeping this file free of logic is what lets the whole
 * flow be tested with fakes, without Docker, a network, or a Groq bill.
 *
 * The AI clients are built per request because their timeout comes from runtime
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
import {
  type ChatClientOptions,
  createChatClient,
} from "../_shared/ai/openai-compatible-client.ts";
import { groqOptionsFromEnv } from "../_shared/ai/groq-config.ts";
import {
  geminiOptionsFromEnv,
  isGeminiConfigured,
} from "../_shared/ai/gemini-config.ts";
import { createAnalysisProvider } from "../_shared/ai/analysis-provider.ts";
import {
  createFallbackAnalysisProvider,
  resolveProviderOrder,
} from "../_shared/ai/fallback-provider.ts";
import { logEvent } from "../_shared/observability/log.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { installationHasherFromEnv } from "../_shared/usage/installation-hash.ts";
import {
  createServiceRoleClient,
  createSupabaseSlotStore,
} from "../_shared/usage/supabase-usage-store.ts";

const serviceClient = createServiceRoleClient();

/**
 * One leg of the analysis chain, bound to credentials but not yet to a budget.
 *
 * The credentials are read once, eagerly, by the caller; the seconds arrive
 * later because the fallback's budget is whatever the primary left behind.
 */
function legFor(options: ChatClientOptions) {
  return (seconds: number) =>
    createAnalysisProvider({
      client: createChatClient({ ...options, timeoutSeconds: seconds }),
    });
}

/**
 * Builds the analysis chain for one request (F18-T06).
 *
 * Both providers' credentials are read HERE, eagerly, and the handler calls this
 * before reserving a slot — so a missing or half-configured key is a loud deploy
 * fault that costs the user nothing. Only the HTTP clients are built lazily,
 * inside the chain, because the fallback's timeout is not known until the
 * primary has failed and the remaining budget has been measured.
 *
 * `geminiPrimary` chooses the ORDER only. With no `GEMINI_API_KEY` the chain is
 * Groq alone with no fallback, which is bit-for-bit the behaviour before F18.
 */
function createAnalysisChain(
  timeoutSeconds: number,
  geminiPrimary: boolean,
  requestId: string,
) {
  const geminiConfigured = isGeminiConfigured();

  if (geminiPrimary && !geminiConfigured) {
    // The one state the matrix calls a config error: an operator flipped the
    // flag but never supplied the key. Serving via Groq is the right behaviour
    // — it is what the flag being off would do — but it must not be silent, or
    // nobody ever learns why Gemini never took a request.
    logEvent("analyze.provider_misconfigured", {
      request_id: requestId,
      flag: "gemini_primary_enabled",
      reason: "GEMINI_API_KEY is not set; serving via Groq alone",
    });
  }

  // Both legs' credentials are read here, before the handler reserves a slot.
  // The Gemini check is key-only by design (F18-T04): a key set WITHOUT a model
  // makes `geminiOptionsFromEnv` throw rather than skipping the leg in silence.
  const order = resolveProviderOrder({
    geminiPrimary,
    groq: legFor(groqOptionsFromEnv(timeoutSeconds)),
    gemini: geminiConfigured
      ? legFor(geminiOptionsFromEnv(timeoutSeconds))
      : null,
  });

  return createFallbackAnalysisProvider({
    primary: order.primary,
    primaryName: order.primaryName,
    fallback: order.fallback,
    fallbackName: order.fallbackName,
    totalSeconds: timeoutSeconds,
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
