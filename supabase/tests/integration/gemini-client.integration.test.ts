/**
 * F18-T08 · The Gemini leg against the real provider — the risk gate.
 *
 * F18 decision 3 bets that Gemini's OpenAI-COMPATIBLE endpoint takes the same
 * request shape Groq already does, so one transport, one prompt and one schema
 * serve both legs. This file is what makes that bet falsifiable.
 *
 * The bet is not obviously safe. Google documents the compat layer as beta and
 * says unsupported parameters are *silently ignored* rather than rejected. If
 * `response_format` were ignored we would get free-form JSON that happens to
 * parse — the exact failure `ai/analysis-provider.ts` records having already
 * been observed once with `json_object` mode, where the model invented its own
 * field names. So it is not enough for the call to succeed: the ANSWER has to
 * prove the constraint was applied.
 *
 * If the schema tests below fail, STOP. Decision 3 is invalid and Gemini's
 * native endpoint becomes necessary — only the client module would change, but
 * the flag must not be flipped until it does.
 *
 * Requires GEMINI_API_KEY; skips otherwise, so `deno test` stays green for
 * anyone without a key. Run with:
 *
 *   GEMINI_API_KEY=<key> GEMINI_MODEL=<model> deno test --allow-net --allow-env supabase/tests
 *
 * These calls spend real free-tier quota, so they are few and small.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createChatClient } from "../../functions/_shared/ai/openai-compatible-client.ts";
import {
  DEFAULT_GEMINI_MODEL,
  GEMINI_DEFAULT_BASE_URL,
} from "../../functions/_shared/ai/gemini-config.ts";
import {
  assertModelAnalysis,
  createAnalysisProvider,
} from "../../functions/_shared/ai/analysis-provider.ts";
import {
  ANALYSIS_OUTPUT_SCHEMA,
  ANALYSIS_RESPONSE_FORMAT,
} from "../../functions/_shared/schemas/analysis-output.schema.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";

const apiKey = Deno.env.get("GEMINI_API_KEY");
const model = Deno.env.get("GEMINI_MODEL") ?? DEFAULT_GEMINI_MODEL;
const baseUrl = Deno.env.get("GEMINI_BASE_URL") ?? GEMINI_DEFAULT_BASE_URL;
const skip = !apiKey;

/**
 * A short synthetic Egyptian electricity bill.
 *
 * Invented, not a real document: these lines are sent to a provider whose free
 * tier permits human review, and they appear in this file's assertions and
 * failure messages. Nothing here belongs to anyone.
 */
const SYNTHETIC_BILL = [
  "شركة جنوب القاهرة لتوزيع الكهرباء",
  "فاتورة كهرباء - أكتوبر 2026",
  "رقم الحساب: 1234567890",
  "المبلغ المستحق: 185.50 جنيه",
  "آخر موعد للسداد: 2026-10-28",
].join("\n");

const NO_CANDIDATES: ExtractedCandidates = {
  dates: [],
  times: [],
  amounts: [],
  phones: [],
  references: [],
};

function client(timeoutSeconds = 30) {
  return createChatClient({
    baseUrl,
    apiKey: apiKey!,
    model,
    timeoutSeconds,
  });
}

// ── 1 · the configured model exists and answers ───────────────────────────

Deno.test({
  name: "[integration] the configured Gemini model answers a real completion",
  ignore: skip,
  fn: async () => {
    // Catches a retired or access-restricted model, which would otherwise
    // surface much later as a baffling ANALYSIS_FAILED with no clue why.
    // `gemini-1.5-flash` is retired; `gemini-2.5-flash` is restricted to
    // accounts with prior 2.5 usage.
    const completion = await client()({
      messages: [
        { role: "system", content: "Reply with exactly one word." },
        { role: "user", content: "Say OK" },
      ],
      maxTokens: 10,
    });

    assert(completion.content.length > 0, "the model must answer");
    assert(
      completion.model.length > 0,
      `expected a model name, got ${completion.model}`,
    );
  },
});

// ── 2 · the generation schema is ACCEPTED ─────────────────────────────────

Deno.test({
  name: "[integration] Gemini accepts ANALYSIS_OUTPUT_SCHEMA without a 400",
  ignore: skip,
  fn: async () => {
    // Deliberately a RAW fetch rather than the client. The transport discards
    // provider error bodies on purpose (§7: they echo the prompt, and the prompt
    // is someone's document) — correct in production, useless for a risk gate.
    // The prompt here is synthetic, so reading the body back is safe, and it is
    // the only way to learn WHICH schema keyword an incompatible provider
    // rejected.
    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: "Extract the document into the schema." },
          { role: "user", content: SYNTHETIC_BILL },
        ],
        temperature: 0,
        max_tokens: 2000,
        response_format: ANALYSIS_RESPONSE_FORMAT,
      }),
      signal: AbortSignal.timeout(30_000),
    });

    const body = await response.text();

    assertEquals(
      response.status,
      200,
      `the schema was rejected — decision 3 may be invalid. Provider said: ${body.slice(0, 1200)}`,
    );
  },
});

// ── 3 · json_schema + strict is HONOURED, not silently ignored ────────────

Deno.test({
  name: "[integration] Gemini honours json_schema strict mode, not ignores it",
  ignore: skip,
  fn: async () => {
    // The whole risk gate. Runs the REAL provider — real prompt builder, real
    // schema, real parser — so a pass here means the Gemini leg is genuinely
    // interchangeable with the Groq one.
    const analyse = createAnalysisProvider({ client: client() });

    const analysis = await analyse({
      ocrText: SYNTHETIC_BILL,
      detectedLanguages: ["ar"],
      candidates: NO_CANDIDATES,
    });

    // `createAnalysisProvider` already ran `assertModelAnalysis`; running it
    // again states the contract this test exists to prove.
    assertModelAnalysis(analysis);

    // The documented failure mode is not a malformed answer but a
    // PLAUSIBLE one with invented field names. Exact key equality is what
    // catches that: free-form JSON would not reproduce the schema's key set.
    assertEquals(
      Object.keys(analysis).sort(),
      [...ANALYSIS_OUTPUT_SCHEMA.required].sort(),
      "the answer's keys are not the schema's — response_format was ignored",
    );

    // And the constrained enums really are constrained.
    assert(
      ["success", "partial", "unsupported"].includes(analysis.status),
      `status outside the schema enum: ${analysis.status}`,
    );
    assert(
      ["high", "medium", "low"].includes(analysis.document_type.confidence),
      `confidence outside the schema enum: ${analysis.document_type.confidence}`,
    );
  },
});

// ── 4 · our credential problem is never the user's fault ──────────────────

Deno.test({
  name: "[integration] a bad Gemini key fails as ANALYSIS_FAILED, not UNAUTHORIZED",
  ignore: skip,
  fn: async () => {
    // A 401 from the provider must never reach the user as though THEY were not
    // signed in — this app has no login screen to send them to.
    const badKey = createChatClient({
      baseUrl,
      apiKey: "definitely-not-a-valid-key",
      model,
      timeoutSeconds: 25,
    });

    const thrown = await assertRejects(
      () => badKey({ messages: [{ role: "user", content: "hi" }] }),
      ApiError,
    );

    assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
    // And it must be marked a provider fault, or the F18-T05 chain would not
    // fail over to Groq when a Gemini key is wrong — the scenario the rollout's
    // verification list exercises deliberately.
    assertEquals((thrown as ApiError).providerFault, true);
  },
});

// ── 5 · a hung provider cannot hold the slot ──────────────────────────────

Deno.test({
  name: "[integration] an impossibly short Gemini timeout aborts rather than hanging",
  ignore: skip,
  fn: async () => {
    // A 1s budget against a real network call: either it genuinely completes or
    // it times out — both are correct, but it must never hang.
    try {
      await client(1)({
        messages: [{ role: "user", content: "Write a long essay about rivers." }],
        maxTokens: 2000,
      });
    } catch (thrown) {
      assert(thrown instanceof ApiError);
      assertEquals((thrown as ApiError).code, "TIMEOUT");
    }
  },
});
