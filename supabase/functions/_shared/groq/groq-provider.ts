/**
 * F06-T11 · `AiAnalysisProvider` — the analysis seam.
 *
 * The endpoint depends on this interface, never on Groq. Swapping providers,
 * or standing in a fake for tests, changes nothing above this line.
 *
 * Schema-constrained generation guarantees the SHAPE of the answer. It says
 * nothing about whether the answer is TRUE: the model can still return a
 * perfectly-typed amount that is not on the page. That is what the validation
 * pipeline (F06-T12) is for, and why this module deliberately stops at
 * structure.
 */

import { ApiError } from "../errors/api-error.ts";
import type { GroqClient } from "./groq-client.ts";
import { type AnalysisPromptInput, buildAnalysisMessages } from "../prompts/analysis-prompt.ts";
import {
  GROQ_ANALYSIS_RESPONSE_FORMAT,
  type ModelAnalysis,
} from "../schemas/groq-output.schema.ts";

/** What the endpoint calls. Implementations must never throw a raw provider error. */
export type AiAnalysisProvider = (
  input: AnalysisPromptInput,
) => Promise<ModelAnalysis>;

/**
 * Bounded, and deliberately not generous.
 *
 * `max_tokens` is RESERVED against the per-minute token quota, not merely
 * capped — measured on 2026-07-26, the tier allows 8000 tokens/minute
 * (`x-ratelimit-limit-tokens`). At 4000 a single analysis claimed over half
 * the minute's budget and three back-to-back calls were rate-limited, which
 * would surface to users as AI_RATE_LIMITED under trivial load.
 *
 * A real electricity bill produced 468 completion tokens, so 2000 leaves
 * roughly 4x headroom for a long official letter while letting several
 * analyses share a minute. It still stops a looping model from burning the
 * whole timeout.
 */
const MAX_OUTPUT_TOKENS = 2000;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

const STATUSES = new Set(["success", "partial", "unsupported"]);
const CONFIDENCES = new Set(["high", "medium", "low"]);

/**
 * Confirms the parsed JSON really is a {@link ModelAnalysis}.
 *
 * Strict mode should make this impossible to fail — which is exactly why it is
 * here. If the provider ever silently drops the constraint (a model change, a
 * plan change, an API regression), an unchecked cast would let a malformed
 * object flow all the way to the device and crash the result screen. Failing
 * here instead costs the user nothing, because the slot is released.
 */
function assertModelAnalysis(value: unknown): ModelAnalysis {
  if (!isRecord(value)) throw ApiError.analysisFailed();

  if (typeof value.status !== "string" || !STATUSES.has(value.status)) {
    throw ApiError.analysisFailed();
  }

  const documentType = value.document_type;
  if (
    !isRecord(documentType) ||
    typeof documentType.type !== "string" ||
    typeof documentType.title !== "string" ||
    typeof documentType.confidence !== "string" ||
    !CONFIDENCES.has(documentType.confidence)
  ) {
    throw ApiError.analysisFailed();
  }

  const summary = value.summary;
  if (
    !isRecord(summary) ||
    typeof summary.short !== "string" ||
    typeof summary.detailed !== "string"
  ) {
    throw ApiError.analysisFailed();
  }

  // Every collection must be present, even when empty: the client iterates
  // them unconditionally, and a missing array would be a null dereference on
  // someone's phone.
  for (
    const key of [
      "key_information",
      "dates",
      "amounts",
      "actions_required",
      "required_documents",
      "instructions",
      "warnings",
      "missing_fields",
    ]
  ) {
    if (!Array.isArray(value[key])) throw ApiError.analysisFailed();
  }

  return value as unknown as ModelAnalysis;
}

export interface GroqProviderOptions {
  readonly client: GroqClient;
  /** Overrides GROQ_MODEL for this provider. */
  readonly model?: string;
}

/**
 * Builds the Groq-backed provider.
 *
 * The model MUST support `response_format: json_schema`. On this account only
 * the `openai/gpt-oss-*` family does; `llama-3.3-70b-versatile` and the rest
 * answer HTTP 400. A model without it returns free-form JSON that happens to
 * parse — verified in practice, and it invented its own field names — so the
 * constraint is not optional decoration.
 */
export function createGroqAnalysisProvider(
  options: GroqProviderOptions,
): AiAnalysisProvider {
  const { client, model } = options;

  return async (input: AnalysisPromptInput): Promise<ModelAnalysis> => {
    const completion = await client({
      messages: buildAnalysisMessages(input),
      model,
      temperature: 0,
      maxTokens: MAX_OUTPUT_TOKENS,
      responseFormat: GROQ_ANALYSIS_RESPONSE_FORMAT,
    });

    let parsed: unknown;
    try {
      parsed = JSON.parse(completion.content);
    } catch {
      // Never attach the raw content: it is a reading of the user's document.
      throw ApiError.analysisFailed();
    }

    return assertModelAnalysis(parsed);
  };
}
