/**
 * F14 · `POST /functions/v1/ocr-document` — the OCR-only endpoint.
 *
 * Wiring only, same discipline as `analyze-document/index.ts`: the sequence
 * lives in `ocr-handler.ts`, every rule lives a layer below that. This file
 * exists so the client can get the raw OCR text and candidates back for
 * on-device review BEFORE the (unmodified) `analyze-document` Groq call.
 *
 * No `GroqClient`, no usage-slot store — this endpoint never touches the
 * daily quota (see `ocr-handler.ts`'s header comment) and never calls Groq.
 */

import { createOcrHandler } from "../_shared/analyze/ocr-handler.ts";
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
      // Azure/Google env vars are read here, not at module load — same
      // reasoning `analyze-document/index.ts` documents: a deployment that
      // never sees an image request (azureOcrEnabled dark) never has to have
      // them configured.
      //
      // Google is optional: the pipeline works fine with Azure alone —
      // unchecked fields simply stay flagged for user review.
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
    }),
  }),
);
