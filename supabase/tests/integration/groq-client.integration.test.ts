/**
 * F06-T09 · The Groq transport against the real provider.
 *
 * The unit tests prove the mapping logic with an injected `fetch`. What only a
 * live call can show is that the endpoint shape, the auth header and — most
 * importantly — the configured MODEL are still valid. Providers retire models,
 * and a decommissioned one would otherwise surface much later as a baffling
 * ANALYSIS_FAILED with no clue why.
 *
 * Requires GROQ_API_KEY in the environment; skips otherwise, so `deno test`
 * stays green for anyone without a key. Run with:
 *
 *   supabase functions serve --env-file supabase/.env      # or export it
 *   GROQ_API_KEY=<key> deno test --allow-net --allow-env supabase/tests
 *
 * These calls cost real tokens, so they are few and small — but NOT smaller
 * than the configured model can answer in. `openai/gpt-oss-*` charges its
 * internal reasoning trace against `max_tokens` BEFORE writing a word of the
 * answer, so a budget of 10 or 50 returns an empty completion (`finish_reason:
 * "length"`) or, under `json_object`, an outright HTTP 400
 * `json_validate_failed` on the empty generation. Both of these tests did
 * exactly that, undetected, because they self-skip without a key and CI has
 * none. They now pass `reasoningEffort: "low"` and a realistic budget, matching
 * what `ai/analysis-provider.ts` sends in production and documents at length.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createChatClient } from "../../functions/_shared/ai/openai-compatible-client.ts";
import {
  DEFAULT_GROQ_MODEL,
  GROQ_BASE_URL,
} from "../../functions/_shared/ai/groq-config.ts";

const apiKey = Deno.env.get("GROQ_API_KEY");
const model = Deno.env.get("GROQ_MODEL") ?? DEFAULT_GROQ_MODEL;
const skip = !apiKey;

Deno.test({
  name: "[integration] the configured model answers a real completion",
  ignore: skip,
  fn: async () => {
    const client = createChatClient({
      baseUrl: GROQ_BASE_URL,
      apiKey: apiKey!,
      model,
      timeoutSeconds: 25,
    });

    const completion = await client({
      messages: [
        { role: "system", content: "Reply with exactly one word." },
        { role: "user", content: "Say OK" },
      ],
      maxTokens: 300,
      reasoningEffort: "low",
    });

    assert(completion.content.length > 0, "the model must answer");
    // If the model were retired the call would have failed, so reaching here
    // is the real assertion; this pins which model actually served us.
    assert(
      completion.model.length > 0,
      `expected a model name, got ${completion.model}`,
    );
  },
});

Deno.test({
  name: "[integration] the provider honours JSON object mode",
  ignore: skip,
  fn: async () => {
    // F06-T11 depends on constrained output; confirm the account and model
    // support it before building on that assumption.
    const client = createChatClient({
      baseUrl: GROQ_BASE_URL,
      apiKey: apiKey!,
      model,
      timeoutSeconds: 25,
    });

    const completion = await client({
      messages: [
        {
          role: "system",
          content: 'Reply with JSON only, of the form {"status":"ok"}.',
        },
        { role: "user", content: "Respond." },
      ],
      responseFormat: { type: "json_object" },
      maxTokens: 300,
      reasoningEffort: "low",
    });

    const parsed = JSON.parse(completion.content);
    assertEquals(typeof parsed, "object");
  },
});

Deno.test({
  name: "[integration] a bad key fails as ANALYSIS_FAILED, not UNAUTHORIZED",
  ignore: skip,
  fn: async () => {
    // Our credential problem must never be reported to the user as though
    // THEY were not signed in.
    const client = createChatClient({
      baseUrl: GROQ_BASE_URL,
      apiKey: "gsk_definitely_not_a_valid_key",
      model,
      timeoutSeconds: 25,
    });

    const thrown = await assertRejects(
      () => client({ messages: [{ role: "user", content: "hi" }] }),
      ApiError,
    );

    assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
  },
});

Deno.test({
  name: "[integration] an impossibly short timeout aborts rather than hanging",
  ignore: skip,
  fn: async () => {
    const client = createChatClient({
      baseUrl: GROQ_BASE_URL,
      apiKey: apiKey!,
      model,
      timeoutSeconds: 1,
    });

    // A 1s budget against a real network call: either it genuinely completes
    // or it times out — both are correct, but it must never hang.
    try {
      await client({
        messages: [{ role: "user", content: "Write a long essay about rivers." }],
        maxTokens: 2000,
      });
    } catch (thrown) {
      assert(thrown instanceof ApiError);
      assertEquals((thrown as ApiError).code, "TIMEOUT");
    }
  },
});
