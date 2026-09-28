/**
 * F06-T11 · Tests for the analysis provider and the generation schema.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import {
  isFallbackEligible,
  ProviderFailure,
} from "../../functions/_shared/ai/provider-failure.ts";
import type {
  ChatClient,
  ChatCompletionRequest,
} from "../../functions/_shared/ai/openai-compatible-client.ts";
import { createAnalysisProvider } from "../../functions/_shared/ai/analysis-provider.ts";
import {
  ANALYSIS_OUTPUT_SCHEMA,
  ANALYSIS_RESPONSE_FORMAT,
  type ModelAnalysis,
} from "../../functions/_shared/schemas/analysis-output.schema.ts";
import type { AnalysisPromptInput } from "../../functions/_shared/prompts/analysis-prompt.ts";

const INPUT: AnalysisPromptInput = {
  ocrText: "فاتورة كهرباء\nالمبلغ: 850.50 جنيه",
  detectedLanguages: ["ar"],
  candidates: { dates: [], times: [], amounts: [], phones: [], references: [] },
};

const VALID: ModelAnalysis = {
  status: "success",
  document_type: { type: "invoice", title: "فاتورة كهرباء", confidence: "high" },
  summary: { short: "فاتورة كهرباء بمبلغ 850.50 جنيه.", detailed: "تفاصيل الفاتورة." },
  key_information: [],
  dates: [],
  amounts: [],
  actions_required: [],
  required_documents: [],
  instructions: [],
  warnings: [],
  missing_fields: [],
};

/** A client that returns whatever content is supplied, recording the request. */
function fakeClient(content: string) {
  const requests: ChatCompletionRequest[] = [];
  const client: ChatClient = (request) => {
    requests.push(request);
    return Promise.resolve({ content, model: "openai/gpt-oss-120b" });
  };
  return { client, requests };
}

/** A signal that never fires, for tests that are not about time. */
const OPEN_SIGNAL = new AbortController().signal;

function providerReturning(value: unknown) {
  const { client, requests } = fakeClient(JSON.stringify(value));
  return { provider: createAnalysisProvider({ client }), requests };
}

// ── the request ───────────────────────────────────────────────────────────

Deno.test("the call is constrained by the json schema", () => {
  // The whole point of the task: without this the model invents its own
  // structure, which was observed in practice with json_object mode.
  assertEquals(ANALYSIS_RESPONSE_FORMAT.type, "json_schema");
  assertEquals(ANALYSIS_RESPONSE_FORMAT.json_schema.strict, true);
  assertEquals(ANALYSIS_RESPONSE_FORMAT.json_schema.name, "document_analysis");
});

Deno.test("the provider sends the schema and a zero temperature", async () => {
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT, OPEN_SIGNAL);

  assertEquals(requests[0].responseFormat, ANALYSIS_RESPONSE_FORMAT);
  assertEquals(requests[0].temperature, 0);
});

Deno.test("the provider bounds the output length", async () => {
  // An unbounded budget lets a looping model burn the entire timeout.
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT, OPEN_SIGNAL);

  assert((requests[0].maxTokens ?? 0) > 0);
});

Deno.test("the provider sends the reasoning effort it is built with", async () => {
  // Groq's gpt-oss models need "low" (GROQ_REASONING_EFFORT); the leg must pass
  // on whatever it was given, unchanged.
  const { client, requests } = fakeClient(JSON.stringify(VALID));
  const provider = createAnalysisProvider({ client, reasoningEffort: "low" });

  await provider(INPUT, OPEN_SIGNAL);

  assertEquals(requests[0].reasoningEffort, "low");
});

Deno.test("no reasoning effort is sent unless one is given", async () => {
  // F20-T06: Mistral takes no such parameter. A default here would reach
  // every provider unasked, and a rejected field is a 4xx that never falls back.
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT, OPEN_SIGNAL);

  assertEquals(requests[0].reasoningEffort, undefined);
});

Deno.test("the provider sends the built prompt messages", async () => {
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT, OPEN_SIGNAL);

  assertEquals(requests[0].messages.length, 2);
  assertEquals(requests[0].messages[0].role, "system");
  assert(requests[0].messages[1].content.includes("فاتورة كهرباء"));
});

// ── the schema itself ─────────────────────────────────────────────────────

Deno.test("the schema uses only keywords strict mode accepts", () => {
  // Groq rejects minLength / maxLength / pattern / format / minimum /
  // maximum / default outright. §30 uses several of them, which is why the
  // generation schema is a separate object from the contract.
  const forbidden = [
    "minLength",
    "maxLength",
    "pattern",
    "format",
    "minimum",
    "maximum",
    "default",
    "$ref",
    "definitions",
  ];
  const serialised = JSON.stringify(ANALYSIS_OUTPUT_SCHEMA);

  for (const keyword of forbidden) {
    assert(
      !serialised.includes(`"${keyword}"`),
      `${keyword} is not allowed in strict mode`,
    );
  }
});

Deno.test("every object in the schema forbids extra properties", () => {
  // Required by strict mode, and it keeps the model from inventing fields the
  // client would reject.
  function walk(node: unknown): void {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    if (typeof node !== "object" || node === null) return;

    const record = node as Record<string, unknown>;
    if (record.type === "object") {
      assertEquals(record.additionalProperties, false);
      assert(Array.isArray(record.required), "objects must list required");
      const properties = Object.keys(
        (record.properties ?? {}) as Record<string, unknown>,
      );
      // Strict mode demands every property be required; optionality is
      // expressed as a nullable type instead.
      assertEquals(
        (record.required as string[]).slice().sort(),
        properties.slice().sort(),
      );
    }
    Object.values(record).forEach(walk);
  }

  walk(ANALYSIS_OUTPUT_SCHEMA);
});

Deno.test("an optional field is nullable rather than absent", () => {
  const time = ANALYSIS_OUTPUT_SCHEMA.properties.dates.items.properties.time;

  assertEquals(time.type, ["string", "null"]);
});

Deno.test("the schema does not ask the model for server-owned fields", () => {
  // A hallucinated session_id would attach an analysis to the wrong document.
  const serialised = JSON.stringify(ANALYSIS_OUTPUT_SCHEMA);

  assert(!serialised.includes("session_id"));
  assert(!serialised.includes("schema_version"));
});

Deno.test("the enums match API_CONTRACT §30", () => {
  assertEquals(ANALYSIS_OUTPUT_SCHEMA.properties.status.enum, [
    "success",
    "partial",
    "unsupported",
  ]);
  assertEquals(ANALYSIS_OUTPUT_SCHEMA.properties.document_type.properties.type.enum, [
    "invoice",
    "receipt",
    "appointment",
    "government",
    "exam",
    "medical",
    "legal",
    "financial",
    "educational",
    "other",
  ]);
  assertEquals(ANALYSIS_OUTPUT_SCHEMA.properties.dates.items.properties.role.enum, [
    "deadline",
    "appointment",
    "issued",
    "expiry",
    "event",
    "period_start",
    "period_end",
  ]);
});

// ── parsing the answer ────────────────────────────────────────────────────

Deno.test("a valid answer is returned as-is", async () => {
  const { provider } = providerReturning(VALID);

  const result = await provider(INPUT, OPEN_SIGNAL);

  assertEquals(result.status, "success");
  assertEquals(result.document_type.title, "فاتورة كهرباء");
});

Deno.test("unparseable content is invalid_output", async () => {
  const { client } = fakeClient("not json at all");
  const provider = createAnalysisProvider({ client });

  const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);

  assertEquals((thrown as ProviderFailure).kind, "invalid_output");
});

Deno.test("the failure never quotes the model output", async () => {
  // The content is a reading of the user's document.
  const { client } = fakeClient("broken: مبلغ 850 جنيه حساب 12345678");
  const provider = createAnalysisProvider({ client });

  const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);
  const message = (thrown as ProviderFailure).message;

  assert(!message.includes("850"));
  assert(!message.includes("12345678"));
});

Deno.test("a wrong shape is rejected rather than passed to the device", async () => {
  // Strict mode should prevent these. The check exists for the day the
  // provider silently drops the constraint — an unchecked cast would crash
  // the result screen on someone's phone instead.
  const malformed: unknown[] = [
    null,
    [],
    "a string",
    { ...VALID, status: "complete" }, // the invented value seen with json_object
    { ...VALID, status: undefined },
    { ...VALID, document_type: { type: "invoice", title: "x" } }, // no confidence
    { ...VALID, document_type: { type: "invoice", title: "x", confidence: "certain" } },
    { ...VALID, summary: { short: "x" } },
    { ...VALID, summary: "just text" },
  ];

  for (const value of malformed) {
    const { provider } = providerReturning(value);
    const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);
    assertEquals(
      (thrown as ProviderFailure).kind,
      "invalid_output",
      `should reject ${JSON.stringify(value)?.slice(0, 60)}`,
    );
  }
});

Deno.test("a missing collection is rejected", async () => {
  // The client iterates these unconditionally; a missing array is a null
  // dereference on the phone.
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
    const value = { ...VALID } as Record<string, unknown>;
    delete value[key];

    const { provider } = providerReturning(value);
    const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);
    assertEquals((thrown as ProviderFailure).kind, "invalid_output", `missing ${key}`);
  }
});

Deno.test("empty collections are accepted", async () => {
  // A document with no dates or amounts is perfectly valid.
  const { provider } = providerReturning(VALID);

  const result = await provider(INPUT, OPEN_SIGNAL);

  assertEquals(result.dates, []);
  assertEquals(result.amounts, []);
});

Deno.test("an unsupported document is a normal answer, not an error", async () => {
  // §31 rule 6: it is a 200 and must not be counted against the quota.
  const { provider } = providerReturning({
    ...VALID,
    status: "unsupported",
    missing_fields: ["everything"],
  });

  const result = await provider(INPUT, OPEN_SIGNAL);

  assertEquals(result.status, "unsupported");
});

// ── the parser's failures are fallback-eligible (F20 matrix row A5) ─────
// F18 treated unusable JSON as the model's considered verdict and never asked a
// second provider. F20 reverses that: a different model may well produce a
// valid answer where this one did not, and the fallback is cheap next to
// failing the user's analysis outright.

Deno.test("unparseable content may fall back", async () => {
  const { client } = fakeClient("not json at all");
  const provider = createAnalysisProvider({ client });

  const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);

  assert(isFallbackEligible((thrown as ProviderFailure).kind));
});

Deno.test("a wrong-shaped answer may fall back", async () => {
  // Valid JSON, valid HTTP, wrong object — exactly what `assertModelAnalysis`
  // exists to catch.
  const { provider } = providerReturning({ status: "success" });

  const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);

  assert(isFallbackEligible((thrown as ProviderFailure).kind));
});

// ── semantic validation runs inside the attempt (F20-T06, §3) ─────────────

Deno.test("a well-shaped answer in English is invalid_output and may fall back", async () => {
  // Passes `assertModelAnalysis`; fails S2. Another model may answer in Arabic.
  const { provider } = providerReturning({
    ...VALID,
    document_type: { type: "invoice", title: "Electricity bill", confidence: "high" },
    summary: {
      short: "An electricity bill of 850.50 EGP.",
      detailed: "This is an electricity bill; the amount due is 850.50 EGP.",
    },
  });

  const thrown = await assertRejects(() => provider(INPUT, OPEN_SIGNAL), ProviderFailure);

  assertEquals((thrown as ProviderFailure).kind, "invalid_output");
  assert(isFallbackEligible((thrown as ProviderFailure).kind));
});

Deno.test("the semantic check is run against this request's own OCR text", async () => {
  // S4 needs the input the leg was given: a summary that echoes it is rejected.
  const page = "يرجى الحضور إلى مكتب السجل المدني بالعباسية يوم الأحد الموافق 2026/10/04 " +
    "ومعكم أصل شهادة الميلاد وصورة البطاقة الشخصية";
  const { provider } = providerReturning({
    ...VALID,
    summary: { short: "ورقة من السجل المدني.", detailed: page },
  });

  const thrown = await assertRejects(
    () => provider({ ...INPUT, ocrText: page }, OPEN_SIGNAL),
    ProviderFailure,
  );

  assertEquals((thrown as ProviderFailure).kind, "invalid_output");
});

Deno.test("the same answer passes when it does not echo the input", async () => {
  // The control for the test above: only the OCR text differs.
  const page = "يرجى الحضور إلى مكتب السجل المدني بالعباسية يوم الأحد الموافق 2026/10/04 " +
    "ومعكم أصل شهادة الميلاد وصورة البطاقة الشخصية";
  const { provider } = providerReturning({
    ...VALID,
    summary: { short: "ورقة من السجل المدني.", detailed: page },
  });

  const result = await provider(INPUT, OPEN_SIGNAL);

  assertEquals(result.summary.detailed, page);
});

// ── the signal ────────────────────────────────────────────────────────────

Deno.test("the leg forwards the signal it is given to the transport", async () => {
  // The leg never picks its own timeout: one request-wide budget governs every
  // attempt (timeout contract §2).
  const { provider, requests } = providerReturning(VALID);
  const controller = new AbortController();

  await provider(INPUT, controller.signal);

  assertEquals(requests[0].signal, controller.signal);
});
