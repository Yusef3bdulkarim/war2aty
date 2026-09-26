/**
 * F06-T09 · OpenAI-compatible chat transport.
 *
 * The only place that speaks HTTP to an analysis provider. Prompt construction
 * is T10 and the schema-constrained call is T11; this layer just gets a request
 * there and a response back, turning provider failures into `ApiError` values
 * the endpoint already knows how to serialise.
 *
 * The provider is named by `baseUrl` alone — every provider reached from here
 * takes the same request shape (Bearer auth, `messages[]`, `response_format`,
 * `temperature`, `max_tokens`), which is what makes one transport enough.
 *
 * The app never learns which provider exists (§9): it talks to the Edge
 * Function, which holds the key. Nothing about the provider reaches the client —
 * not its name, its model, nor its error text.
 *
 * PRIVACY (§7, §51): no prompt, no completion and no key is ever logged. Error
 * paths deliberately discard the provider's response body, which echoes the
 * prompt — and the prompt contains the user's document.
 */

import { ApiError } from "../errors/api-error.ts";

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
  /** Defaults to the model the client was built with. */
  readonly model?: string;
  /**
   * Defaults to 0. Document analysis is extraction, not creativity — the same
   * paper should yield the same reading twice.
   */
  readonly temperature?: number;
  readonly maxTokens?: number;
  readonly responseFormat?: ChatResponseFormat;
  /**
   * `openai/gpt-oss-*` models spend part of `maxTokens` on an internal
   * reasoning trace before writing the answer — see
   * {@link AnalysisProviderOptions} for why the analysis provider always sets
   * this to `"low"`. Left optional here because it is meaningless for
   * non-reasoning models.
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
   * Required, and deliberately not defaulted here: a default in this module
   * would have to name one provider's model, which is exactly the knowledge
   * the seam exists to keep out. Each provider's config module supplies its
   * own (`groq-config.ts`, `gemini-config.ts`).
   */
  readonly model: string;
  readonly timeoutSeconds: number;
  /** Injected so tests never touch the network. */
  readonly fetchImpl?: typeof fetch;
}

export type ChatClient = (
  request: ChatCompletionRequest,
) => Promise<ChatCompletion>;

/**
 * Maps a provider HTTP status to an `ApiError`.
 *
 * The provider's own message is never forwarded: it quotes the prompt on
 * validation errors, and the prompt holds the document.
 */
function errorForStatus(status: number): ApiError {
  // Every status reaching here is the provider declining to answer, so all of
  // them are provider faults and all are eligible for failover (F18-T05).
  //
  // 429 is the one the client can act on — it is asked to try again later. On a
  // free tier it is also the COMMON case, and the whole reason the chain exists.
  if (status === 429) return ApiError.aiRateLimited().asProviderFault();
  // 5xx and the rest are ours to own; the user only ever sees "analysis
  // failed", never that a third party was involved.
  return ApiError.analysisFailed().asProviderFault();
}

interface ChatApiResponse {
  model?: string;
  choices?: Array<{ message?: { content?: string } }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

/**
 * Builds a client bound to a base URL, key, model and timeout.
 *
 * The timeout is the point of this task. Without one, a hung provider
 * connection holds the reserved slot until it expires and leaves the user
 * staring at a spinner; with it, the server gives up first, releases the slot
 * and answers 408 (§31 TIMEOUT).
 */
export function createChatClient(options: ChatClientOptions): ChatClient {
  const {
    baseUrl,
    apiKey,
    model: defaultModel,
    timeoutSeconds,
    fetchImpl = fetch,
  } = options;

  const chatCompletionsUrl = `${baseUrl}/chat/completions`;

  return async (request: ChatCompletionRequest): Promise<ChatCompletion> => {
    const body = {
      model: request.model ?? defaultModel,
      messages: request.messages,
      temperature: request.temperature ?? 0,
      ...(request.maxTokens === undefined ? {} : { max_tokens: request.maxTokens }),
      ...(request.responseFormat === undefined ? {} : { response_format: request.responseFormat }),
      ...(request.reasoningEffort === undefined ? {} : { reasoning_effort: request.reasoningEffort }),
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
        signal: AbortSignal.timeout(
          Math.max(1, Math.floor(timeoutSeconds)) * 1000,
        ),
      });
    } catch (thrown) {
      // A timeout aborts the fetch; so does a dropped connection. Both mean we
      // have no answer, and the caller must release the slot either way.
      if (thrown instanceof DOMException && thrown.name === "TimeoutError") {
        throw ApiError.timeout().asProviderFault();
      }
      throw ApiError.analysisFailed().asProviderFault();
    }

    if (!response.ok) {
      // Drain the body so the connection is not left dangling, and discard it:
      // provider error bodies echo the prompt.
      await response.body?.cancel();
      throw errorForStatus(response.status);
    }

    let payload: ChatApiResponse;
    try {
      payload = await response.json();
    } catch {
      // A 200 whose body is not JSON is a broken response, not an answer.
      throw ApiError.analysisFailed().asProviderFault();
    }

    const content = payload.choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.length === 0) {
      // A well-formed HTTP 200 carrying nothing usable is still a failed
      // analysis, and must not be counted against the user's quota.
      //
      // A provider fault, unlike the PARSER's failures in
      // `analysis-provider.ts`: no answer at all is worth asking a second
      // provider about, whereas an answer of the wrong shape is not.
      throw ApiError.analysisFailed().asProviderFault();
    }

    return {
      content,
      model: payload.model ?? body.model,
      promptTokens: payload.usage?.prompt_tokens,
      completionTokens: payload.usage?.completion_tokens,
    };
  };
}
