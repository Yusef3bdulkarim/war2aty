/**
 * F36-T16 · `POST /functions/v1/explain-document` — the one-call endpoint.
 *
 * Wiring only; the sequence lives in `explain-handler.ts` and every rule lives
 * a layer below that. Keeping this file free of logic is what lets the whole
 * flow be tested with fakes, without Docker, a network, or a provider bill.
 *
 * The two chain factories are called per request because their time budgets
 * come from runtime config, which an operator can change without a redeploy.
 * Everything else is built once per worker so a missing environment variable
 * fails at startup.
 *
 * ── Gemma (leg 3 of explaining) is deliberately absent ───────────────────
 * T11 marks it optional: the premise that Gemma 4 honours
 * `responseJsonSchema` on the native API is unmeasured (trap #2), and T18's
 * benchmark is where it is measured. Until then the chain is two legs
 * (Mistral → Groq), which is an acceptable outcome. If T18 confirms, add
 * the leg here with `gemmaOptionsFromEnv` and `createGemmaNativeClient`.
 */

import { createExplainHandler } from "../_shared/explain/explain-handler.ts";
import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { loadRuntimeConfig } from "../_shared/config/supabase-runtime-config.ts";
import { createChatClient } from "../_shared/ai/openai-compatible-client.ts";
import { GROQ_REASONING_EFFORT, groqOptionsFromEnv } from "../_shared/ai/groq-config.ts";
import { mistralOptionsFromEnv } from "../_shared/ai/mistral-config.ts";
import { geminiReadingOptionsFromEnv } from "../_shared/ai/gemini-config.ts";
import { createReadingChain } from "../_shared/ai/reading-chain.ts";
import { createExplainChain } from "../_shared/ai/explain-chain.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { installationHasherFromEnv } from "../_shared/usage/installation-hash.ts";
import {
  createServiceRoleClient,
  createSupabaseSlotStore,
} from "../_shared/usage/supabase-usage-store.ts";

const serviceClient = createServiceRoleClient();

/**
 * Builds the reading chain for one request.
 *
 * Credentials and model ids are read HERE, eagerly, so a deploy fault
 * (missing key or missing `GEMINI_OCR_MODELS`) throws before the handler
 * reserves a slot (matrix row A8).
 */
function createReader(stageSeconds: number, requestId: string) {
  const { gemini, models } = geminiReadingOptionsFromEnv();
  return createReadingChain({
    gemini,
    models,
    totalSeconds: stageSeconds,
    requestId,
  });
}

/**
 * Builds the explaining chain for one request.
 *
 * Credentials are read HERE, eagerly, for the same reason as the reading
 * chain: a missing Mistral or Groq key is a deploy fault that costs no slot.
 *
 * Mistral first, Groq on a fallback-eligible failure — the same order as
 * `analyze-document`, but over a different prompt and schema. Groq keeps its
 * `reasoning_effort`; Mistral is not a reasoning model and gets none.
 *
 * Gemma is absent: see the file header.
 */
function createExplainer(stageSeconds: number, requestId: string) {
  return createExplainChain({
    mistral: { client: createChatClient(mistralOptionsFromEnv()) },
    groq: {
      client: createChatClient(groqOptionsFromEnv()),
      reasoningEffort: GROQ_REASONING_EFFORT,
    },
    totalSeconds: stageSeconds,
    requestId,
  });
}

Deno.serve(
  createEndpoint({
    name: "explain-document",
    method: "POST",
    handle: createExplainHandler({
      verifyToken: createSupabaseTokenVerifier(),
      loadConfig: () => loadRuntimeConfig(serviceClient),
      slots: createSupabaseSlotStore(serviceClient),
      createReader,
      createExplainer,
      hashInstallation: installationHasherFromEnv(),
      now: () => new Date(),
    }),
  }),
);
