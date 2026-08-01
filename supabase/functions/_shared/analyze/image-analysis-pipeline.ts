/**
 * F13-T11 · The online image-analysis pipeline.
 *
 * The one place that puts T04–T08 in order for a single image: Azure reads it,
 * T05's extractors turn Azure's text into candidates, T06 scores them against
 * Azure's own word confidences, T08 decides whether a Google second opinion is
 * worth the extra call and merges the two readings. Nothing above this module
 * knows Azure or Google exist — `analyze-handler.ts` sees only `ocrText` /
 * `candidates` / `verification`, the same shape the offline (Tesseract) path
 * already hands it.
 *
 * ── Why Google's failure is swallowed here, not propagated ────────────────
 * `cross-provider-validator.ts` already documents this: a `null` google
 * reading means "not consulted — not needed, or the call itself failed", and
 * either way the field Azure could not confirm simply stays flagged for
 * review. A second opinion is an enhancement to trust, never a dependency an
 * otherwise-successful analysis should fail over. Azure failing IS
 * propagated: it is the primary, only read of the document, and per the
 * locked decision (§ Locked decisions #2) a failed-while-online call must
 * fail outright rather than silently degrade.
 *
 * PRIVACY (§7, §51): no OCR text, candidate value, or image byte is ever
 * logged here.
 */

import type { AzureDocumentIntelligenceClient } from "../azure/azure-client.ts";
import type { GoogleDocumentAiClient } from "../google/google-client.ts";
import { extractAmounts } from "../extractors/amount-extractor.ts";
import { extractDates } from "../extractors/date-extractor.ts";
import { extractPhones } from "../extractors/phone-extractor.ts";
import { extractReferences } from "../extractors/reference-extractor.ts";
import { extractTimes } from "../extractors/time-extractor.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import {
  mergeProviderVerification,
  needsGoogleSecondOpinion,
} from "../verification/cross-provider-validator.ts";
import type { CrossProviderVerification } from "../verification/cross-provider-validator.ts";
import { verifyCandidates } from "../verification/field-verification.ts";

export interface ImageAnalysisInput {
  readonly data: Uint8Array;
  readonly mimeType: string;
}

export interface ImageAnalysisResult {
  readonly ocrText: string;
  readonly candidates: ExtractedCandidates;
  readonly verification: CrossProviderVerification;
}

export type ImageAnalysisPipeline = (
  input: ImageAnalysisInput,
) => Promise<ImageAnalysisResult>;

export interface ImageAnalysisPipelineOptions {
  readonly azureClient: AzureDocumentIntelligenceClient;
  readonly googleClient: GoogleDocumentAiClient;
}

/** Runs every T05 extractor over one OCR reading, in `ExtractedCandidates`' own field order. */
function runExtractors(text: string): ExtractedCandidates {
  return {
    dates: extractDates(text),
    times: extractTimes(text),
    amounts: extractAmounts(text),
    phones: extractPhones(text),
    references: extractReferences(text),
  };
}

/**
 * Builds the pipeline. Bound to one Azure/Google client pair per request —
 * same lifecycle as `createGroqAnalysisProvider`, since both carry a timeout
 * that comes from runtime config.
 */
export function createImageAnalysisPipeline(
  options: ImageAnalysisPipelineOptions,
): ImageAnalysisPipeline {
  const { azureClient, googleClient } = options;

  return async (input: ImageAnalysisInput): Promise<ImageAnalysisResult> => {
    const azureResult = await azureClient(input.data, input.mimeType);
    const candidates = runExtractors(azureResult.content);
    const azureVerification = verifyCandidates({
      content: azureResult.content,
      words: azureResult.words,
      candidates,
    });

    let googleCandidates: ExtractedCandidates | null = null;
    if (needsGoogleSecondOpinion(azureVerification)) {
      try {
        const googleResult = await googleClient(input.data, input.mimeType);
        googleCandidates = runExtractors(googleResult.content);
      } catch {
        // Swallowed by design — see the header comment. Azure's own result
        // still stands; the fields it could not confirm simply stay flagged.
        googleCandidates = null;
      }
    }

    const verification = mergeProviderVerification({
      azureCandidates: candidates,
      azureVerification,
      googleCandidates,
    });

    return { ocrText: azureResult.content, candidates, verification };
  };
}
