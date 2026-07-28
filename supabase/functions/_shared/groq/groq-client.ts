/**
 * F06-T09 · Groq transport.
 *
 * The only place that speaks HTTP to Groq. Prompt construction is T10 and the
 * schema-constrained call is T11; this layer just gets a request there and a
 * response back, turning provider failures into `ApiError` values the endpoint
 * already knows how to serialise.
 *
 * The app never learns Groq exists (§9): it talks to the Edge Function, which
 * holds the key. Nothing about the provider reaches the client — not its name,
 * its model, nor its error text.
 *
 * PRIVACY (§7, §51): no prompt, no completion and no key is ever logged. Error
 * paths deliberately discard the provider's response body, which echoes the
 * prompt — and the prompt contains the user's document.
 */

import { ApiError } from "../errors/api-error.ts";

const GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions";

/**
 * The model this service is built around, and the one `.env.example` sets.
 *
 * It MUST support `response_format: json_schema`: F06-T11 sends one on every
 * call, and a model without it answers 400. This is the default for a
 * directly-constructed client and for tests — never a fallback on the
 * production path, which refuses to guess (see {@link groqOptionsFromEnv}).
 */
export const DEFAULT_GROQ_MODEL = "openai/gpt-oss-120b";

export type GroqRole = "system" | "user" | "assistant";

export interface GroqMessage {
  readonly role: GroqRole;
  readonly content: string;
}

/**
 * `response_format` as the OpenAI-compatible API expects it. Left open so
 * F06-T11 can pass a `json_schema` without changing this layer.
 */
export type GroqResponseFormat =
  | { readonly type: "text" }
  | { readonly type: "json_object" }
  | { readonly type: "json_schema"; readonly json_schema: unknown };

export interface GroqCompletionRequest {
  readonly messages: readonly GroqMessage[];
  /** Defaults to `GROQ_MODEL` from the environment. */
  readonly model?: string;
  /**
   * Defaults to 0. Document analysis is extraction, not creativity — the same
   * paper should yield the same reading twice.
   */
  readonly temperature?: number;
  readonly maxTokens?: number;
  readonly responseFormat?: GroqResponseFormat;
}

export interface GroqCompletion {
  /** The assistant message text. Parsing it is the caller's job. */
  readonly content: string;
  readonly model: string;
  readonly promptTokens?: number;
  readonly completionTokens?: number;
}

export interface GroqClientOptions {
  readonly apiKey: string;
  readonly model?: string;
  readonly timeoutSeconds: number;
  /** Injected so tests never touch the network. */
  readonly fetchImpl?: typeof fetch;
}

export type GroqClient = (
  request: GroqCompletionRequest,
) => Promise<GroqCompletion>;

/**
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `GROQ_API_KEY` or `GROQ_MODEL` is missing. Both are deploy faults,
 * and both are fatal at startup rather than per request — see below for why the
 * model is not defaulted.
 */
export function groqOptionsFromEnv(timeoutSeconds: number): GroqClientOptions {
  const apiKey = Deno.env.get("GROQ_API_KEY");

  if (!apiKey) {
    // A deploy fault, not a user error. Surfaced loudly here rather than as a
    // baffling 500 on every analysis.
    throw new Error("GROQ_API_KEY is not set.");
  }

  // Deliberately NOT defaulted. A model that cannot serve `json_schema` fails
  // EVERY analysis with a 400 the user only ever sees as ANALYSIS_FAILED — a
  // total outage wearing the costume of a flaky provider. Falling back would
  // hide exactly the mistake worth shouting about, so an unset model is a
  // startup error like the key above.
  //
  // Read with `.trim()` rather than `??`: an env var set to "" is a string, so
  // `??` would wave it through and send an empty model name to Groq.
  const model = Deno.env.get("GROQ_MODEL")?.trim();

  if (!model) {
    throw new Error(
      "GROQ_MODEL is not set. It must name a model that supports " +
        "`response_format: json_schema` — see supabase/.env.example.",
    );
  }

  return { apiKey, model, timeoutSeconds };
}

/**
 * Maps a provider HTTP status to an `ApiError`.
 *
 * The provider's own message is never forwarded: it quotes the prompt on
 * validation errors, and the prompt holds the document.
 */
function errorForStatus(status: number): ApiError {
  // 429 is the one the client can act on — it is asked to try again later.
  if (status === 429) return ApiError.aiRateLimited();
  // 5xx and the rest are ours to own; the user only ever sees "analysis
  // failed", never that a third party was involved.
  return ApiError.analysisFailed();
}

interface GroqApiResponse {
  model?: string;
  choices?: Array<{ message?: { content?: string } }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

/**
 * Builds a client bound to a key, model and timeout.
 *
 * The timeout is the point of this task. Without one, a hung provider
 * connection holds the reserved slot until it expires and leaves the user
 * staring at a spinner; with it, the server gives up first, releases the slot
 * and answers 408 (§31 TIMEOUT).
 */
export function createGroqClient(options: GroqClientOptions): GroqClient {
  const {
    apiKey,
    model: defaultModel = DEFAULT_GROQ_MODEL,
    timeoutSeconds,
    fetchImpl = fetch,
  } = options;

  return async (request: GroqCompletionRequest): Promise<GroqCompletion> => {
    const body = {
      model: request.model ?? defaultModel,
      messages: request.messages,
      temperature: request.temperature ?? 0,
      ...(request.maxTokens === undefined ? {} : { max_tokens: request.maxTokens }),
      ...(request.responseFormat === undefined ? {} : { response_format: request.responseFormat }),
    };

    let response: Response;
    try {
      response = await fetchImpl(GROQ_CHAT_COMPLETIONS_URL, {
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
        throw ApiError.timeout();
      }
      throw ApiError.analysisFailed();
    }

    if (!response.ok) {
      // Drain the body so the connection is not left dangling, and discard it:
      // provider error bodies echo the prompt.
      await response.body?.cancel();
      throw errorForStatus(response.status);
    }

    let payload: GroqApiResponse;
    try {
      payload = await response.json();
    } catch {
      throw ApiError.analysisFailed();
    }

    const content = payload.choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.length === 0) {
      // A well-formed HTTP 200 carrying nothing usable is still a failed
      // analysis, and must not be counted against the user's quota.
      throw ApiError.analysisFailed();
    }

    return {
      content,
      model: payload.model ?? body.model,
      promptTokens: payload.usage?.prompt_tokens,
      completionTokens: payload.usage?.completion_tokens,
    };
  };
}
