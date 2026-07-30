/**
 * F06-T11 · Tests for the analysis provider and the generation schema.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import type {
  GroqClient,
  GroqCompletionRequest,
} from "../../functions/_shared/groq/groq-client.ts";
import { createGroqAnalysisProvider } from "../../functions/_shared/groq/groq-provider.ts";
import {
  GROQ_ANALYSIS_RESPONSE_FORMAT,
  GROQ_OUTPUT_SCHEMA,
  type ModelAnalysis,
} from "../../functions/_shared/schemas/groq-output.schema.ts";
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
  const requests: GroqCompletionRequest[] = [];
  const client: GroqClient = (request) => {
    requests.push(request);
    return Promise.resolve({ content, model: "openai/gpt-oss-120b" });
  };
  return { client, requests };
}

function providerReturning(value: unknown) {
  const { client, requests } = fakeClient(JSON.stringify(value));
  return { provider: createGroqAnalysisProvider({ client }), requests };
}

// ── the request ───────────────────────────────────────────────────────────

Deno.test("the call is constrained by the json schema", () => {
  // The whole point of the task: without this the model invents its own
  // structure, which was observed in practice with json_object mode.
  assertEquals(GROQ_ANALYSIS_RESPONSE_FORMAT.type, "json_schema");
  assertEquals(GROQ_ANALYSIS_RESPONSE_FORMAT.json_schema.strict, true);
  assertEquals(GROQ_ANALYSIS_RESPONSE_FORMAT.json_schema.name, "document_analysis");
});

Deno.test("the provider sends the schema and a zero temperature", async () => {
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT);

  assertEquals(requests[0].responseFormat, GROQ_ANALYSIS_RESPONSE_FORMAT);
  assertEquals(requests[0].temperature, 0);
});

Deno.test("the provider bounds the output length", async () => {
  // An unbounded budget lets a looping model burn the entire timeout.
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT);

  assert((requests[0].maxTokens ?? 0) > 0);
});

Deno.test("the provider sends the built prompt messages", async () => {
  const { provider, requests } = providerReturning(VALID);

  await provider(INPUT);

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
  const serialised = JSON.stringify(GROQ_OUTPUT_SCHEMA);

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

  walk(GROQ_OUTPUT_SCHEMA);
});

Deno.test("an optional field is nullable rather than absent", () => {
  const time = GROQ_OUTPUT_SCHEMA.properties.dates.items.properties.time;

  assertEquals(time.type, ["string", "null"]);
});

Deno.test("the schema does not ask the model for server-owned fields", () => {
  // A hallucinated session_id would attach an analysis to the wrong document.
  const serialised = JSON.stringify(GROQ_OUTPUT_SCHEMA);

  assert(!serialised.includes("session_id"));
  assert(!serialised.includes("schema_version"));
});

Deno.test("the enums match API_CONTRACT §30", () => {
  assertEquals(GROQ_OUTPUT_SCHEMA.properties.status.enum, [
    "success",
    "partial",
    "unsupported",
  ]);
  assertEquals(GROQ_OUTPUT_SCHEMA.properties.document_type.properties.type.enum, [
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
  assertEquals(GROQ_OUTPUT_SCHEMA.properties.dates.items.properties.role.enum, [
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

  const result = await provider(INPUT);

  assertEquals(result.status, "success");
  assertEquals(result.document_type.title, "فاتورة كهرباء");
});

Deno.test("unparseable content becomes ANALYSIS_FAILED", async () => {
  const { client } = fakeClient("not json at all");
  const provider = createGroqAnalysisProvider({ client });

  const thrown = await assertRejects(() => provider(INPUT), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("the failure never quotes the model output", async () => {
  // The content is a reading of the user's document.
  const { client } = fakeClient("broken: مبلغ 850 جنيه حساب 12345678");
  const provider = createGroqAnalysisProvider({ client });

  const thrown = await assertRejects(() => provider(INPUT), ApiError);
  const message = (thrown as ApiError).message;

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
    const thrown = await assertRejects(() => provider(INPUT), ApiError);
    assertEquals(
      (thrown as ApiError).code,
      "ANALYSIS_FAILED",
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
    const thrown = await assertRejects(() => provider(INPUT), ApiError);
    assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED", `missing ${key}`);
  }
});

Deno.test("empty collections are accepted", async () => {
  // A document with no dates or amounts is perfectly valid.
  const { provider } = providerReturning(VALID);

  const result = await provider(INPUT);

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

  const result = await provider(INPUT);

  assertEquals(result.status, "unsupported");
});
