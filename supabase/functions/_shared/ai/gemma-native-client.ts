/**
 * EXPERIMENT · Gemma over the Gemini API's NATIVE `generateContent`, shaped as
 * a `ChatClient` so the shared analysis provider (shape + semantic checks)
 * runs on it unchanged.
 *
 * Why a second path: through the OpenAI-compatible endpoint, Gemma 4 did not
 * honour `response_format: json_schema` — it answered free JSON (numbers
 * where the schema says strings, a trailing ``` fence). The native API takes
 * the schema as `responseJsonSchema`, which reportedly IS enforced for
 * Gemma 4. This client exists to measure that.
 *
 * - The system message is folded into the user turn, because Gemma models on
 *   the Gemini API have not always accepted `systemInstruction`.
 * - `thought` parts are skipped, as the OCR client does.
 * - HTTP failures map through `providerFailureForStatus`, like every leg.
 *
 * Not wired into production. Benchmark legs only (`GEMMA_ENDPOINT=native`).
 */

import type { ChatClient, ChatCompletionRequest } from "./openai-compatible-client.ts";
import { ProviderFailure, providerFailureForStatus } from "./provider-failure.ts";

export const GEMINI_NATIVE_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";

export interface GemmaNativeClientOptions {
  readonly apiKey: string;
  readonly model: string;
  readonly fetchImpl?: typeof fetch;
}

interface GenerateContentResponse {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: unknown; thought?: unknown }> };
    finishReason?: unknown;
  }>;
  promptFeedback?: { blockReason?: unknown };
  usageMetadata?: { promptTokenCount?: unknown; candidatesTokenCount?: unknown };
  modelVersion?: unknown;
}

function interrupted(thrown: unknown): ProviderFailure {
  if (thrown instanceof DOMException && thrown.name === "TimeoutError") {
    return new ProviderFailure("timeout");
  }
  return new ProviderFailure("network");
}

function schemaOf(request: ChatCompletionRequest): unknown {
  const format = request.responseFormat;
  if (format?.type !== "json_schema") return undefined;
  const wrapper = format.json_schema as { schema?: unknown } | undefined;
  return wrapper?.schema;
}

export function createGemmaNativeClient(options: GemmaNativeClientOptions): ChatClient {
  const { apiKey, model: defaultModel, fetchImpl = fetch } = options;

  return async (request) => {
    const model = request.model ?? defaultModel;
    const system = request.messages.filter((m) => m.role === "system").map((m) => m.content);
    const rest = request.messages.filter((m) => m.role !== "system");

    const contents = rest.map((m, index) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{
        text: index === 0 && system.length > 0
          ? `${system.join("\n\n")}\n\n${m.content}`
          : m.content,
      }],
    }));

    const schema = schemaOf(request);
    const body = {
      contents,
      generationConfig: {
        temperature: request.temperature ?? 0,
        maxOutputTokens: request.maxTokens,
        responseMimeType: schema === undefined ? "text/plain" : "application/json",
        ...(schema === undefined ? {} : { responseJsonSchema: schema }),
      },
    };

    let response: Response;
    try {
      response = await fetchImpl(`${GEMINI_NATIVE_BASE_URL}/models/${model}:generateContent`, {
        method: "POST",
        headers: { "x-goog-api-key": apiKey, "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: request.signal,
      });
    } catch (thrown) {
      throw interrupted(thrown);
    }
    if (!response.ok) throw providerFailureForStatus(response.status);

    let payload: GenerateContentResponse;
    try {
      payload = await response.json();
    } catch (thrown) {
      throw interrupted(thrown);
    }

    if (payload.promptFeedback?.blockReason !== undefined) {
      throw new ProviderFailure("invalid_output");
    }
    const candidate = payload.candidates?.[0];
    if (candidate === undefined || candidate.finishReason !== "STOP") {
      throw new ProviderFailure("invalid_output");
    }

    let content = "";
    for (const part of candidate.content?.parts ?? []) {
      if (part.thought === true) continue;
      if (typeof part.text === "string") content += part.text;
    }

    const usage = payload.usageMetadata;
    return {
      content,
      model: typeof payload.modelVersion === "string" ? payload.modelVersion : model,
      promptTokens: typeof usage?.promptTokenCount === "number"
        ? usage.promptTokenCount
        : undefined,
      completionTokens: typeof usage?.candidatesTokenCount === "number"
        ? usage.candidatesTokenCount
        : undefined,
    };
  };
}
