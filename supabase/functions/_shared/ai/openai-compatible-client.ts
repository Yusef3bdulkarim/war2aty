/**
 * F06-T09 · OpenAI-compatible chat transport.
 *
 * The only place that speaks HTTP to an analysis provider. It sends a request
 * and gets a response back. Prompt construction (F06-T10) and the
 * schema-constrained call (F06-T11) live above it.
 *
 * The provider is named by `baseUrl` alone. Every provider reached from here
 * takes the same request shape (Bearer auth, `messages[]`, `response_format`,
 * `temperature`, `max_tokens`), which is why one transport is enough.
 *
 * ── Failures (F20-T04) ────────────────────────────────────────────────────
 * Every failure is thrown as a `ProviderFailure` with a closed `kind` (failure
 * matrix §1), never as an `ApiError`. Whether a failure may fall back to a
 * second provider, and which §31 code it becomes, is decided above this layer
 * from the kind alone. This module only reports what happened.
 *
 * ── Time (F20-T04) ────────────────────────────────────────────────────────
 * There is no timeout of its own. Each call takes the caller's `AbortSignal`,
 * usually from a request `Deadline`, so one budget governs every attempt in a
 * request (timeout contract §2) instead of each client carrying a fixed one.
 *
 * The app never learns which provider exists (§9): it talks to the Edge
 * Function, which holds the key. Nothing about the provider reaches the client:
 * not its name, its model, nor its error text.
 *
 * PRIVACY (§7, §51): no prompt, no completion and no key is ever logged. Error
 * bodies are discarded unread. The one exception is a 400, where exactly one
 * machine-readable field (`error.code`) is read, and the body is dropped
 * without being logged or attached to anything.
 */

import { ProviderFailure, providerFailureForStatus } from "./provider-failure.ts";

export type ChatRole = "system" | "user" | "assistant";

export interface ChatMessage {
  readonly role: ChatRole;
  readonly content: string;
}

/**
 * `response_format` as the OpenAI-compatible API expects it. Left open so
 * F06-T11 can pass a `json_schema` without changing this layer.
 */
export type ChatResponseFormat =
  | { readonly type: "text" }
  | { readonly type: "json_object" }
  | { readonly type: "json_schema"; readonly json_schema: unknown };

export interface ChatCompletionRequest {
  readonly messages: readonly ChatMessage[];
  /**
   * Aborts the call. Required: an unbounded provider call would hold the
   * reserved slot until it lapsed and leave the user on a spinner. Abort with a
   * `TimeoutError` reason (as `AbortSignal.timeout` and `Deadline.signal` do)
   * to have it reported as `timeout`. Any other abort is reported as `network`.
   */
  readonly signal: AbortSignal;
  /** Defaults to the model the client was built with. */
  readonly model?: string;
  /**
   * Defaults to 0. Document analysis is extraction, not creativity: the same
   * paper should yield the same reading twice.
   */
  readonly temperature?: number;
  readonly maxTokens?: number;
  readonly responseFormat?: ChatResponseFormat;
  /**
   * `openai/gpt-oss-*` models spend part of `maxTokens` on an internal
   * reasoning trace before writing the answer. See
   * {@link AnalysisProviderOptions} for when the analysis provider sets it.
   * Optional because it is meaningless for non-reasoning models, and some
   * providers reject it.
   */
  readonly reasoningEffort?: "low" | "medium" | "high";
}

export interface ChatCompletion {
  /** The assistant message text. Parsing it is the caller's job. */
  readonly content: string;
  readonly model: string;
  readonly promptTokens?: number;
  readonly completionTokens?: number;
}

export interface ChatClientOptions {
  /**
   * The provider's OpenAI-compatible root, with no trailing slash — e.g.
   * `https://api.groq.com/openai/v1`. `/chat/completions` is appended.
   */
  readonly baseUrl: string;
  readonly apiKey: string;
  /**
   * Required, and deliberately not defaulted here. A default in this module
   * would have to name one provider's model, which is exactly the knowledge
   * the seam exists to keep out. Each provider's config module supplies its
   * own.
   */
  readonly model: string;
  /** Injected so tests never touch the network. */
  readonly fetchImpl?: typeof fetch;
}

export type ChatClient = (
  request: ChatCompletionRequest,
) => Promise<ChatCompletion>;

/**
 * Groq's error code for a completion that failed its own strict-schema check.
 * It arrives as an HTTP 400, but it describes the MODEL's output, not our
 * request, so it is `invalid_output` rather than `bad_request`.
 */
const SCHEMA_VALIDATION_FAILED_CODE = "json_validate_failed";

/**
 * Classifies a non-2xx response and releases its body.
 *
 * Only a 400 is read at all, and only for `error.code`. Every other body is
 * cancelled unread.
 */
async function failureForResponse(response: Response): Promise<ProviderFailure> {
  if (response.status === 400 && await errorCodeOf(response) === SCHEMA_VALIDATION_FAILED_CODE) {
    return new ProviderFailure("invalid_output");
  }
  // Already consumed when it was a 400, in which case this is a no-op.
  await response.body?.cancel().catch(() => {});
  return providerFailureForStatus(response.status);
}

/** `error.code` of a JSON error body, or `null`. Nothing else is read. */
async function errorCodeOf(response: Response): Promise<string | null> {
  try {
    const body: unknown = await response.json();
    const error = (body as { error?: { code?: unknown } } | null)?.error;
    return typeof error?.code === "string" ? error.code : null;
  } catch {
    return null;
  }
}

interface ChatApiResponse {
  model?: string;
  choices?: Array<{ message?: { content?: string }; finish_reason?: string }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

/** Builds a client bound to a base URL, key and model. */
export function createChatClient(options: ChatClientOptions): ChatClient {
  const { baseUrl, apiKey, model: defaultModel, fetchImpl = fetch } = options;

  const chatCompletionsUrl = `${baseUrl}/chat/completions`;

  return async (request: ChatCompletionRequest): Promise<ChatCompletion> => {
    const body = {
      model: request.model ?? defaultModel,
      messages: request.messages,
      temperature: request.temperature ?? 0,
      ...(request.maxTokens === undefined ? {} : { max_tokens: request.maxTokens }),
      ...(request.responseFormat === undefined ? {} : { response_format: request.responseFormat }),
      ...(request.reasoningEffort === undefined
        ? {}
        : { reasoning_effort: request.reasoningEffort }),
    };

    let response: Response;
    try {
      response = await fetchImpl(chatCompletionsUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
        signal: request.signal,
      });
    } catch (thrown) {
      // Our own budget running out and the connection dropping both mean we
      // have no answer. Only the first is a timeout, which is what lets the
      // caller answer 408 rather than a generic failure.
      if (thrown instanceof DOMException && thrown.name === "TimeoutError") {
        throw new ProviderFailure("timeout");
      }
      throw new ProviderFailure("network");
    }

    if (!response.ok) throw await failureForResponse(response);

    let payload: ChatApiResponse;
    try {
      payload = await response.json();
    } catch {
      // A 200 whose body is not JSON is a broken response, not an answer.
      throw new ProviderFailure("invalid_output");
    }

    const choice = payload.choices?.[0];
    const content = choice?.message?.content;
    if (typeof content !== "string" || content.length === 0) {
      // A well-formed HTTP 200 carrying nothing usable is still a failed
      // analysis, and must not be counted against the user's quota.
      throw new ProviderFailure("invalid_output");
    }

    if (choice?.finish_reason === "length") {
      // Cut off at `max_tokens`. Whatever arrived is at best a prefix of the
      // answer, and parsing a prefix of JSON is how silently-partial analyses
      // happen.
      throw new ProviderFailure("invalid_output");
    }

    return {
      content,
      model: payload.model ?? body.model,
      promptTokens: payload.usage?.prompt_tokens,
      completionTokens: payload.usage?.completion_tokens,
    };
  };
}
