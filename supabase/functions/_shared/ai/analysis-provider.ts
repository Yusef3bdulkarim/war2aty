/**
 * F06-T11 · `AiAnalysisProvider` — the analysis seam.
 *
 * The endpoint depends on this interface, never on a provider. Swapping
 * providers, or standing in a fake for tests, changes nothing above this line.
 *
 * Schema-constrained generation guarantees the SHAPE of the answer. It says
 * nothing about whether the answer is TRUE: the model can still return a
 * perfectly-typed amount that is not on the page. That is what the validation
 * pipeline (F06-T12) is for, and why this module deliberately stops at
 * structure, plus the semantic hard rejects (F20-T05) that decide whether an
 * answer is usable at all.
 *
 * ── Two types, two audiences (F20-T04) ────────────────────────────────────
 * - An {@link AnalysisLeg} is ONE provider, called once, within a signal it is
 *   given. It throws only `ProviderFailure`, which reports what went wrong
 *   and says nothing about the wire.
 * - An {@link AiAnalysisProvider} is what the endpoint calls. It owns the time
 *   budget and any fallback between legs, and throws only `ApiError`, which is
 *   already mapped to §31.
 *
 * `fallback-provider.ts` turns legs into a provider.
 */

import { ProviderFailure } from "./provider-failure.ts";
import type { ChatClient, ChatCompletionRequest } from "./openai-compatible-client.ts";
import { assertSemanticallyValid } from "../analysis/semantic-validation.ts";
import { type AnalysisPromptInput, buildAnalysisMessages } from "../prompts/analysis-prompt.ts";
import { ANALYSIS_RESPONSE_FORMAT, type ModelAnalysis } from "../schemas/analysis-output.schema.ts";

/** What the endpoint calls. Throws only `ApiError`, never a raw provider error. */
export type AiAnalysisProvider = (
  input: AnalysisPromptInput,
) => Promise<ModelAnalysis>;

/**
 * One provider, one attempt. Throws only `ProviderFailure`.
 *
 * `signal` bounds the attempt. It usually comes from the request's `Deadline`,
 * so the leg never decides its own timeout.
 */
export type AnalysisLeg = (
  input: AnalysisPromptInput,
  signal: AbortSignal,
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

/** Fresh per throw, so no two failures ever share a stack. */
function invalidOutput(): ProviderFailure {
  return new ProviderFailure("invalid_output");
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
 *
 * A failure is `invalid_output` (matrix row A5): the provider answered, but
 * not with something usable. That makes it fallback-eligible, since a second
 * model may well produce a valid answer where this one did not.
 */
export function assertModelAnalysis(value: unknown): ModelAnalysis {
  if (!isRecord(value)) throw invalidOutput();

  if (typeof value.status !== "string" || !STATUSES.has(value.status)) {
    throw invalidOutput();
  }

  const documentType = value.document_type;
  if (
    !isRecord(documentType) ||
    typeof documentType.type !== "string" ||
    typeof documentType.title !== "string" ||
    typeof documentType.confidence !== "string" ||
    !CONFIDENCES.has(documentType.confidence)
  ) {
    throw invalidOutput();
  }

  const summary = value.summary;
  if (
    !isRecord(summary) ||
    typeof summary.short !== "string" ||
    typeof summary.detailed !== "string"
  ) {
    throw invalidOutput();
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
    if (!Array.isArray(value[key])) throw invalidOutput();
  }

  return value as unknown as ModelAnalysis;
}

export interface AnalysisProviderOptions {
  readonly client: ChatClient;
  /** Overrides the client's own model for this provider. */
  readonly model?: string;
  /**
   * Sent as `reasoning_effort` only when set. It is a per-provider setting,
   * so nothing here defaults it: Groq's reasoning models need it
   * (`GROQ_REASONING_EFFORT`), and Mistral is sent none (F20-T06). A default
   * would reach every new provider unasked, and a provider that rejects the
   * field answers 4xx, which is `bad_request` and never falls back.
   */
  readonly reasoningEffort?: ChatCompletionRequest["reasoningEffort"];
}

/**
 * Builds the schema-constrained analysis provider over a chat client.
 *
 * The model MUST support `response_format: json_schema`. On Groq only the
 * `openai/gpt-oss-*` family does; `llama-3.3-70b-versatile` and the rest
 * answer HTTP 400. A model without it returns free-form JSON that happens to
 * parse — verified in practice, and it invented its own field names — so the
 * constraint is not optional decoration.
 *
 * Every attempt checks the answer twice before returning it:
 * `assertModelAnalysis` for its shape, then `assertSemanticallyValid` (§3,
 * S1–S4) for whether it is usable. Both fail as `invalid_output`, so a second
 * provider gets its chance at the same text (matrix row A5).
 */
export function createAnalysisProvider(
  options: AnalysisProviderOptions,
): AnalysisLeg {
  const { client, model, reasoningEffort } = options;

  return async (input: AnalysisPromptInput, signal: AbortSignal): Promise<ModelAnalysis> => {
    const completion = await client({
      messages: buildAnalysisMessages(input),
      signal,
      model,
      temperature: 0,
      maxTokens: MAX_OUTPUT_TOKENS,
      responseFormat: ANALYSIS_RESPONSE_FORMAT,
      reasoningEffort,
    });

    let parsed: unknown;
    try {
      parsed = JSON.parse(completion.content);
    } catch {
      // Never attach the raw content: it is a reading of the user's document.
      throw invalidOutput();
    }

    return assertSemanticallyValid(assertModelAnalysis(parsed), input.ocrText);
  };
}
