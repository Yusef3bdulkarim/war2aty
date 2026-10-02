/**
 * F14, rewired in F20-T13 · `POST /functions/v1/ocr-document` — the OCR-only
 * endpoint.
 *
 * Wiring only, same discipline as `analyze-document/index.ts`: the sequence
 * lives in `ocr-handler.ts`, every rule lives a layer below that. This file
 * exists so the app can get the reading and its candidates back for on-device
 * review BEFORE it asks `analyze-document` for the analysis.
 *
 * No chat client and no usage-slot store: this endpoint never touches the
 * daily quota (see `ocr-handler.ts`'s header comment) and never analyses.
 */

import { createOcrHandler } from "../_shared/analyze/ocr-handler.ts";
import { createImageOcrPipeline } from "../_shared/analyze/image-ocr-pipeline.ts";
import { createGeminiOcrClient } from "../_shared/ai/gemini-ocr-client.ts";
import { geminiOptionsFromEnv } from "../_shared/ai/gemini-config.ts";
import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { loadRuntimeConfig } from "../_shared/config/supabase-runtime-config.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { createServiceRoleClient } from "../_shared/usage/supabase-usage-store.ts";

const serviceClient = createServiceRoleClient();

Deno.serve(
  createEndpoint({
    name: "ocr-document",
    method: "POST",
    handle: createOcrHandler({
      verifyToken: createSupabaseTokenVerifier(),
      loadConfig: () => loadRuntimeConfig(serviceClient),
      // `GEMINI_*` is read here, per request, not at module load: a
      // deployment with online reading switched off never has to have it,
      // and one that does but lacks it fails loudly as INTERNAL_ERROR (O6).
      createPipeline: () =>
        createImageOcrPipeline({
          geminiClient: createGeminiOcrClient(geminiOptionsFromEnv()),
        }),
    }),
  }),
);
