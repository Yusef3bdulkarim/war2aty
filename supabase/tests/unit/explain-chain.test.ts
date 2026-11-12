/**
 * F36-T11 · Tests for the explaining chain.
 *
 * Driven through fake `ChatClient`s, one per leg, so what is pinned is the
 * wiring on top of `createLegChain` (whose routing `leg-chain.test.ts` already
 * covers): the order of the legs, what each is sent, what counts as a usable
 * answer, and the §31 codes this stage can end on. Entirely offline.
 */

import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  assertModelExplanation,
  createExplainChain,
  DEFAULT_EXPLAIN_ATTEMPT_CAP_MS,
  DEFAULT_EXPLAIN_MIN_FALLBACK_MS,
  DEFAULT_EXPLAIN_STAGE_SECONDS,
  EXPLAIN_EVENT,
} from "../../functions/_shared/ai/explain-chain.ts";
import type {
  ChatClient,
  ChatCompletionRequest,
} from "../../functions/_shared/ai/openai-compatible-client.ts";
import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";
import { EXPLAIN_SYSTEM_PROMPT } from "../../functions/_shared/prompts/explain-prompt.ts";
import { EXPLAIN_RESPONSE_FORMAT } from "../../functions/_shared/schemas/explain-output.schema.ts";
import type { ModelExplanation } from "../../functions/_shared/schemas/explain-output.schema.ts";

const REQUEST_ID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";
const READING = "مدرسة النور اجتماع أولياء الأمور 2026/11/20";

const EXPLANATION: ModelExplanation = {
  status: "success",
  paper: { title: "جواب من مدرسة النور" },
  explain: ["دي ورقة من مدرسة النور."],
  todo: { required: true, text: "روح الاجتماع." },
  date: { date: "2026-11-20", time: null, text: "اجتماع أولياء الأمور" },
  caution: null,
  contact: null,
  place: null,
};

/** What a fake leg does when called. */
type Behaviour =
  | { readonly answers: unknown }
  | { readonly rawContent: string }
  | { readonly fails: ProviderFailure["kind"] };

function fakeClient(behaviour: Behaviour, seen: ChatCompletionRequest[]): ChatClient {
  return (request) => {
    seen.push(request);
    if ("fails" in behaviour) return Promise.reject(new ProviderFailure(behaviour.fails));
    const content = "rawContent" in behaviour
      ? behaviour.rawContent
      : JSON.stringify(behaviour.answers);
    return Promise.resolve({ content, model: "fake" });
  };
}

function setup(
  behaviours: { mistral: Behaviour; groq: Behaviour; gemma?: Behaviour },
  overrides: Partial<Parameters<typeof createExplainChain>[0]> = {},
) {
  const seen = { mistral: [], groq: [], gemma: [] } as Record<
    "mistral" | "groq" | "gemma",
    ChatCompletionRequest[]
  >;
  const lines: { event: string; fields: Record<string, unknown> }[] = [];
  const chain = createExplainChain({
    mistral: { client: fakeClient(behaviours.mistral, seen.mistral), model: "ministral-14b" },
    groq: {
      client: fakeClient(behaviours.groq, seen.groq),
      model: "openai/gpt-oss-120b",
      reasoningEffort: "low",
    },
    gemma: behaviours.gemma === undefined
      ? undefined
      : { client: fakeClient(behaviours.gemma, seen.gemma), model: "gemma-4-26b" },
    requestId: REQUEST_ID,
    log: (event, fields) => lines.push({ event, fields: fields as Record<string, unknown> }),
    ...overrides,
  });
  return { chain, seen, lines };
}

const run = (chain: ReturnType<typeof setup>["chain"]) => chain({ readingText: READING });

// ── routing ───────────────────────────────────────────────────────────────

Deno.test("the first leg answering ends the chain", async () => {
  const { chain, seen, lines } = setup({
    mistral: { answers: EXPLANATION },
    groq: { fails: "network" },
    gemma: { fails: "network" },
  });
  assertEquals(await run(chain), EXPLANATION);
  assertEquals([seen.mistral.length, seen.groq.length, seen.gemma.length], [1, 0, 0]);
  assertEquals(lines.length, 1);
  assertEquals(lines[0].event, EXPLAIN_EVENT);
  assertEquals(lines[0].fields.provider, "mistral");
  assertEquals(lines[0].fields.failed_over, false);
});

Deno.test("a rate-limited first leg falls to the second", async () => {
  const { chain, seen, lines } = setup({
    mistral: { fails: "rate_limited" },
    groq: { answers: EXPLANATION },
    gemma: { fails: "network" },
  });
  assertEquals(await run(chain), EXPLANATION);
  assertEquals([seen.mistral.length, seen.groq.length, seen.gemma.length], [1, 1, 0]);
  assertEquals(lines[0].fields.provider, "groq");
  assertEquals(lines[0].fields.primary_failure, "rate_limited");
});

Deno.test("two failures reach the third leg, Gemma", async () => {
  const { chain, seen, lines } = setup({
    mistral: { fails: "upstream_unavailable" },
    groq: { fails: "rate_limited" },
    gemma: { answers: EXPLANATION },
  });
  assertEquals(await run(chain), EXPLANATION);
  assertEquals([seen.mistral.length, seen.groq.length, seen.gemma.length], [1, 1, 1]);
  assertEquals(lines[0].fields.provider, "gemma");
});

Deno.test("a leg that answers the wrong shape falls through like any failure", async () => {
  const { chain, seen } = setup({
    mistral: { answers: { status: "success" } },
    groq: { rawContent: "```json\n{}\n```" },
    gemma: { answers: EXPLANATION },
  });
  assertEquals(await run(chain), EXPLANATION);
  assertEquals(seen.gemma.length, 1);
});

Deno.test("a bad key stops the chain: a deploy fault is not papered over", async () => {
  const { chain, seen } = setup({
    mistral: { fails: "auth" },
    groq: { answers: EXPLANATION },
  });
  const error = await assertRejects(() => run(chain), ApiError);
  assertEquals(error.code, "INTERNAL_ERROR");
  assertEquals(seen.groq.length, 0);
});

Deno.test("the last leg's failure is the one the request ends on", async () => {
  const { chain } = setup({
    mistral: { fails: "rate_limited" },
    groq: { fails: "rate_limited" },
    gemma: { fails: "invalid_output" },
  });
  const error = await assertRejects(() => run(chain), ApiError);
  assertEquals(error.code, "ANALYSIS_FAILED");
});

Deno.test("Gemma is optional: two legs is a legal chain", async () => {
  const { chain, seen } = setup({
    mistral: { fails: "network" },
    groq: { fails: "network" },
  });
  await assertRejects(() => run(chain), ApiError);
  assertEquals(seen.gemma.length, 0);
});

// ── what each leg is sent ─────────────────────────────────────────────────

Deno.test("every leg is sent the explain prompt, the strict schema and its own model", async () => {
  const { chain, seen } = setup({
    mistral: { fails: "network" },
    groq: { fails: "network" },
    gemma: { answers: EXPLANATION },
  });
  await run(chain);

  for (
    const [leg, model] of [["mistral", "ministral-14b"], ["groq", "openai/gpt-oss-120b"], [
      "gemma",
      "gemma-4-26b",
    ]] as const
  ) {
    const [request] = seen[leg];
    assertEquals(request.model, model);
    assertEquals(request.messages[0].content, EXPLAIN_SYSTEM_PROMPT);
    assert(request.messages[1].content.includes(READING));
    assertEquals(request.responseFormat, EXPLAIN_RESPONSE_FORMAT);
    assertEquals(request.temperature, 0);
  }
});

Deno.test("reasoning effort reaches Groq and nobody else", async () => {
  const { chain, seen } = setup({
    mistral: { fails: "network" },
    groq: { fails: "network" },
    gemma: { answers: EXPLANATION },
  });
  await run(chain);
  assertEquals(seen.mistral[0].reasoningEffort, undefined);
  assertEquals(seen.groq[0].reasoningEffort, "low");
  assertEquals(seen.gemma[0].reasoningEffort, undefined);
});

// ── time ──────────────────────────────────────────────────────────────────

Deno.test("the defaults let all three legs run when the first two hang", () => {
  // 8 s + 8 s leaves 4 s of the 20 s stage, which clears the 3 s floor.
  const left = DEFAULT_EXPLAIN_STAGE_SECONDS * 1000 - 2 * DEFAULT_EXPLAIN_ATTEMPT_CAP_MS;
  assert(left >= DEFAULT_EXPLAIN_MIN_FALLBACK_MS);
});

// ── privacy ───────────────────────────────────────────────────────────────

Deno.test("the log line names providers and kinds, never the reading or the answer", async () => {
  const { chain, lines } = setup({
    mistral: { fails: "rate_limited" },
    groq: { answers: EXPLANATION },
  });
  await run(chain);
  const logged = JSON.stringify(lines);
  assert(!logged.includes("النور"));
  assert(!logged.includes("اجتماع"));
});

Deno.test("an unparseable answer fails without carrying its content", async () => {
  const { chain } = setup({
    mistral: { rawContent: "سر المستخدم {" },
    groq: { rawContent: "سر المستخدم {" },
  });
  const error = await assertRejects(() => run(chain), ApiError);
  assert(!JSON.stringify(error).includes("سر المستخدم"));
});

// ── assertModelExplanation ────────────────────────────────────────────────

Deno.test("a well-formed explanation passes through unchanged", () => {
  assertEquals(assertModelExplanation(EXPLANATION), EXPLANATION);
});

Deno.test("every card may be null; a filled card passes", () => {
  const full: ModelExplanation = {
    ...EXPLANATION,
    caution: { text: "بلّغ المدرسة." },
    contact: { name: "مدرسة النور", phone: "0453312244" },
    place: { text: "شارع الجمهورية" },
  };
  assertEquals(assertModelExplanation(full), full);
});

Deno.test("each malformed answer is invalid_output", () => {
  const bad: [string, unknown][] = [
    ["not an object", "text"],
    ["an array", []],
    ["partial status, which is the server's", { ...EXPLANATION, status: "partial" }],
    ["no status", { ...EXPLANATION, status: undefined }],
    ["title not a string", { ...EXPLANATION, paper: { title: 3 } }],
    ["explain not an array", { ...EXPLANATION, explain: "x" }],
    ["explain holds a non-string", { ...EXPLANATION, explain: ["x", 4] }],
    ["todo.required a string", { ...EXPLANATION, todo: { required: "yes", text: "x" } }],
    ["todo null", { ...EXPLANATION, todo: null }],
    ["date missing text", { ...EXPLANATION, date: { date: "2026-11-20", time: null } }],
    ["date time undefined", { ...EXPLANATION, date: { date: "2026-11-20", text: "x" } }],
    ["caution not an object", { ...EXPLANATION, caution: "warn" }],
    ["contact without phone", { ...EXPLANATION, contact: { name: "x" } }],
    ["place a number", { ...EXPLANATION, place: 5 }],
    ["a card absent rather than null", { ...EXPLANATION, place: undefined }],
  ];
  for (const [label, value] of bad) {
    const thrown = assertThrows(() => assertModelExplanation(value), ProviderFailure, "", label);
    assertEquals((thrown as ProviderFailure).kind, "invalid_output", label);
  }
});

Deno.test("length is not this check's job: an over-long answer still passes", () => {
  // §33's caps are T12's; checking them here would need no reading but would
  // fail a leg whose answer T12 could simply trim.
  const long = { ...EXPLANATION, explain: ["ا".repeat(5000)] };
  assertEquals(assertModelExplanation(long), long);
});
