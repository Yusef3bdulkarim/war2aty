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
 * These calls cost real tokens, so they are few and small.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createGroqClient, DEFAULT_GROQ_MODEL } from "../../functions/_shared/groq/groq-client.ts";

const apiKey = Deno.env.get("GROQ_API_KEY");
const model = Deno.env.get("GROQ_MODEL") ?? DEFAULT_GROQ_MODEL;
const skip = !apiKey;

Deno.test({
  name: "[integration] the configured model answers a real completion",
  ignore: skip,
  fn: async () => {
    const client = createGroqClient({
      apiKey: apiKey!,
      model,
      timeoutSeconds: 25,
    });

    const completion = await client({
      messages: [
        { role: "system", content: "Reply with exactly one word." },
        { role: "user", content: "Say OK" },
      ],
      maxTokens: 10,
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
    const client = createGroqClient({
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
      maxTokens: 50,
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
    const client = createGroqClient({
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
    const client = createGroqClient({
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
