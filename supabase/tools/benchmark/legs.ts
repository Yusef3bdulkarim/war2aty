/**
 * F20-T08 · The analysis legs the tools run, built exactly as production
 * builds them: the shared analysis provider over the shared client, from each
 * provider's own config module.
 *
 * `recordingFetch` lets a benchmark see what the leg deliberately hides. The
 * leg reports every unusable answer as one `invalid_output`. T09 needs to know
 * which: a completion cut off at `max_tokens`, a schema failure, or a
 * semantic reject. Recording at the fetch layer answers that without adding a
 * benchmark-only switch to production code.
 */

import {
  type AnalysisLeg,
  createAnalysisProvider,
} from "../../functions/_shared/ai/analysis-provider.ts";
import { createChatClient } from "../../functions/_shared/ai/openai-compatible-client.ts";
import {
  GROQ_REASONING_EFFORT,
  groqOptionsFromEnv,
} from "../../functions/_shared/ai/groq-config.ts";
import { mistralOptionsFromEnv } from "../../functions/_shared/ai/mistral-config.ts";

export type AnalyserName = "mistral" | "groq";

export const ANALYSERS: readonly AnalyserName[] = ["mistral", "groq"];

/**
 * Pause between documents, from each free tier's limits. Groq's is the
 * binding one: 8,000 tokens a minute, and each call reserves its 2,000-token
 * `max_tokens` on top of a ~1,500-token prompt, so about two calls a minute.
 * Mistral's free tier allows one request a second.
 */
export const DEFAULT_DELAY_MS: Readonly<Record<AnalyserName, number>> = {
  mistral: 2_000,
  groq: 30_000,
};

/**
 * One leg, reading its credentials from the environment.
 *
 * @throws when the provider's `*_API_KEY` or `*_MODEL` is missing, naming the
 * variable only.
 */
export function analysisLeg(
  name: AnalyserName,
  fetchImpl?: typeof fetch,
): AnalysisLeg {
  switch (name) {
    case "mistral":
      return createAnalysisProvider({
        client: createChatClient({ ...mistralOptionsFromEnv(), fetchImpl }),
      });
    case "groq":
      return createAnalysisProvider({
        client: createChatClient({ ...groqOptionsFromEnv(), fetchImpl }),
        reasoningEffort: GROQ_REASONING_EFFORT,
      });
  }
}

/** What one chat-completions response carried. Held in memory, never printed. */
export interface RecordedResponse {
  readonly status: number;
  readonly finishReason: string | null;
  readonly promptTokens: number | null;
  readonly completionTokens: number | null;
  /** The assistant message: a reading of the user's document. */
  readonly content: string | null;
}

export interface RecordingFetch {
  readonly fetchImpl: typeof fetch;
  /** The most recent response, or `null` when none arrived. */
  last(): RecordedResponse | null;
  reset(): void;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

/**
 * Wraps `fetch` to keep the last response's finish reason, token usage and
 * content. The caller still gets the original response, unread. An error
 * body is never read, the same rule the client keeps.
 */
export function recordingFetch(inner: typeof fetch = fetch): RecordingFetch {
  let last: RecordedResponse | null = null;

  const fetchImpl: typeof fetch = async (input, init) => {
    const response = await inner(input, init);
    if (!response.ok) {
      last = {
        status: response.status,
        finishReason: null,
        promptTokens: null,
        completionTokens: null,
        content: null,
      };
      return response;
    }

    let body: Record<string, unknown> | null = null;
    try {
      body = await response.clone().json();
    } catch {
      body = null;
    }
    const choice = (body?.choices as Array<Record<string, unknown>> | undefined)
      ?.[0];
    const usage = body?.usage as Record<string, unknown> | undefined;
    const content = (choice?.message as Record<string, unknown> | undefined)
      ?.content;

    last = {
      status: response.status,
      finishReason: typeof choice?.finish_reason === "string" ? choice.finish_reason : null,
      promptTokens: numberOrNull(usage?.prompt_tokens),
      completionTokens: numberOrNull(usage?.completion_tokens),
      content: typeof content === "string" ? content : null,
    };
    return response;
  };

  return {
    fetchImpl,
    last: () => last,
    reset: () => {
      last = null;
    },
  };
}
