/**
 * F36-T09 · Tests for the `explain-document` generation schema.
 *
 * Two jobs. The schema must be legal in strict structured-output mode, and it
 * must ask the model for exactly the fields API_CONTRACT §33 says it writes —
 * no more (§33.2 removed three) and no fewer.
 *
 * The strict-subset walker is NOT a copy of the analysis schema's. That one
 * checks `record.type === "object"`, which a nullable card
 * (`type: ["object", "null"]`) does not satisfy, so reusing it would pass
 * silently on exactly the four nodes that are new here.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  EXPLAIN_MAX_PARAGRAPHS,
  EXPLAIN_OUTPUT_SCHEMA,
  EXPLAIN_PAGE_MAX_CHARS,
  EXPLAIN_PARAGRAPH_MAX_CHARS,
  EXPLAIN_RESPONSE_FORMAT,
  EXPLAIN_TITLE_MAX_CHARS,
  type ModelExplanation,
} from "../../functions/_shared/schemas/explain-output.schema.ts";

type Node = Record<string, unknown>;

function isNode(value: unknown): value is Node {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** True for `"object"` and for any type array that contains it, e.g. nullable. */
function isObjectType(type: unknown): boolean {
  return type === "object" || (Array.isArray(type) && type.includes("object"));
}

/** Every schema node, depth first, with the dotted path that reaches it. */
function* nodes(node: unknown, path = ""): Generator<[string, Node]> {
  if (Array.isArray(node)) {
    for (const [index, child] of node.entries()) yield* nodes(child, `${path}[${index}]`);
    return;
  }
  if (!isNode(node)) return;
  yield [path, node];
  for (const [key, child] of Object.entries(node)) yield* nodes(child, `${path}.${key}`);
}

/** Every property path the schema declares, e.g. `date.time`, `contact.phone`. */
function propertyPaths(node: Node, prefix = ""): string[] {
  const properties = node.properties;
  if (!isNode(properties)) return [];
  return Object.entries(properties).flatMap(([name, child]) => {
    const path = prefix === "" ? name : `${prefix}.${name}`;
    return [path, ...(isNode(child) ? propertyPaths(child, path) : [])];
  });
}

// ── strict-subset legality ────────────────────────────────────────────────

Deno.test("the schema uses only keywords strict mode accepts", () => {
  // Checked as KEYS, not as a substring of the serialised text: the
  // descriptions are prose, and a description may say "format" harmlessly.
  const forbidden = new Set([
    "minLength",
    "maxLength",
    "pattern",
    "format",
    "minimum",
    "maximum",
    "default",
    "minItems",
    "maxItems",
    "$ref",
    "definitions",
    "$defs",
    "anyOf",
    "oneOf",
    "allOf",
  ]);

  for (const [path, node] of nodes(EXPLAIN_OUTPUT_SCHEMA)) {
    for (const key of Object.keys(node)) {
      // `properties` holds field NAMES, which could in principle collide.
      if (path.endsWith(".properties")) continue;
      assert(!forbidden.has(key), `${key} at ${path || "root"} is not allowed in strict mode`);
    }
  }
});

Deno.test("every object, nullable ones included, forbids extra properties", () => {
  let objects = 0;
  for (const [path, node] of nodes(EXPLAIN_OUTPUT_SCHEMA)) {
    if (!isObjectType(node.type)) continue;
    objects++;
    assertEquals(node.additionalProperties, false, `${path || "root"} allows extra properties`);
  }
  // Root, paper, todo, and the four nullable cards.
  assertEquals(objects, 7, "an object was added or lost; check it is covered");
});

Deno.test("every property of every object is required, so optional means nullable", () => {
  for (const [path, node] of nodes(EXPLAIN_OUTPUT_SCHEMA)) {
    if (!isObjectType(node.type)) continue;
    const declared = Object.keys(isNode(node.properties) ? node.properties : {}).sort();
    assert(Array.isArray(node.required), `${path || "root"} must list required`);
    assertEquals(
      [...node.required as string[]].sort(),
      declared,
      `${path || "root"}: required and properties disagree`,
    );
  }
});

Deno.test("the nullable nodes are exactly the four optional cards and the optional time", () => {
  // Nullability is the only way this schema says "optional", so an accidental
  // extra one would let the model omit something §33 says is never null.
  const nullable: string[] = [];
  for (const [path, node] of nodes(EXPLAIN_OUTPUT_SCHEMA)) {
    if (Array.isArray(node.type) && node.type.includes("null")) nullable.push(path);
  }

  assertEquals(nullable.sort(), [
    ".properties.caution",
    ".properties.contact",
    ".properties.date",
    ".properties.date.properties.time",
    ".properties.place",
  ]);
});

Deno.test("explain and todo are never nullable (§33)", () => {
  const { explain, todo, status, paper } = EXPLAIN_OUTPUT_SCHEMA.properties;

  for (const node of [explain, todo, status, paper]) {
    assert(!Array.isArray(node.type), "a field §33 says is never null is nullable");
  }
});

// ── every §33 field, and only those ───────────────────────────────────────

Deno.test("the schema asks for exactly the fields §33 says the model writes", () => {
  assertEquals(propertyPaths(EXPLAIN_OUTPUT_SCHEMA as unknown as Node).sort(), [
    "caution",
    "caution.text",
    "contact",
    "contact.name",
    "contact.phone",
    "date",
    "date.date",
    "date.text",
    "date.time",
    "explain",
    "paper",
    "paper.title",
    "place",
    "place.text",
    "status",
    "todo",
    "todo.required",
    "todo.text",
  ]);
});

Deno.test("the envelope is the server's: the model is never asked to echo it", () => {
  // A hallucinated session id would attach an explanation to the wrong
  // request.
  const paths = propertyPaths(EXPLAIN_OUTPUT_SCHEMA as unknown as Node);

  assert(!paths.includes("session_id"));
  assert(!paths.includes("explain_schema_version"));
});

Deno.test("paper_type, confidence and basis do not exist (§33.2)", () => {
  // The approved design draws none of them; a model-chosen value nothing reads
  // can only be wrong.
  const keys = [...nodes(EXPLAIN_OUTPUT_SCHEMA)].flatMap(([path, node]) =>
    path.endsWith(".properties") ? Object.keys(node) : []
  );

  for (const banned of ["paper_type", "confidence", "basis", "ocr_text", "reading"]) {
    assert(!keys.includes(banned), `${banned} must not be a field`);
  }
});

Deno.test("no card carries a title or a label: the app owns them (§33.3)", () => {
  const keys = [...nodes(EXPLAIN_OUTPUT_SCHEMA)].flatMap(([path, node]) =>
    path.endsWith(".properties") ? Object.keys(node) : []
  );

  // `paper.title` is the one header line §33.1 defines, and is not a card's.
  assertEquals(keys.filter((key) => key === "title" || key === "label"), ["title"]);
});

Deno.test("the model can say success or unsupported, never partial (§33.4)", () => {
  // `partial` means the server removed something it could not ground. Only the
  // server knows that, so a model claiming it would be reporting on a check it
  // never ran.
  assertEquals([...EXPLAIN_OUTPUT_SCHEMA.properties.status.enum], ["success", "unsupported"]);
});

Deno.test("the parsed type and the schema agree on every top-level field", () => {
  // A typed sample, so the compiler rejects a field the interface lacks, and
  // the test rejects one the schema lacks.
  const sample: ModelExplanation = {
    status: "success",
    paper: { title: "فاتورة الكهربا" },
    explain: ["دي فاتورة كهربا."],
    todo: { required: true, text: "ادفعها." },
    date: { date: "2026-11-20", time: null, text: "آخر ميعاد" },
    caution: null,
    contact: { name: "الشركة", phone: "19999" },
    place: null,
  };

  assertEquals(Object.keys(sample).sort(), [...EXPLAIN_OUTPUT_SCHEMA.required].sort());
});

// ── the response format and the caps ──────────────────────────────────────

Deno.test("the response format is a strict json_schema over this schema", () => {
  assertEquals(EXPLAIN_RESPONSE_FORMAT.type, "json_schema");
  assertEquals(EXPLAIN_RESPONSE_FORMAT.json_schema.strict, true);
  assertEquals(EXPLAIN_RESPONSE_FORMAT.json_schema.name, "document_explanation");
  assertEquals(EXPLAIN_RESPONSE_FORMAT.json_schema.schema, EXPLAIN_OUTPUT_SCHEMA);
});

Deno.test("the caps are §33's numbers", () => {
  // Written once here and read by the prompt (T10) and the page cap (T12), so
  // the two cannot drift. The title cap is §33.1's measured one-line limit and
  // the page cap is §33.3's measured 75 s of voice.
  assertEquals(EXPLAIN_TITLE_MAX_CHARS, 24);
  assertEquals(EXPLAIN_MAX_PARAGRAPHS, 4);
  assertEquals(EXPLAIN_PARAGRAPH_MAX_CHARS, 220);
  assertEquals(EXPLAIN_PAGE_MAX_CHARS, 850);
});

Deno.test("the caps are stated to the model, since the schema cannot enforce them", () => {
  const { paper, explain } = EXPLAIN_OUTPUT_SCHEMA.properties;

  assert(paper.properties.title.description.includes(String(EXPLAIN_TITLE_MAX_CHARS)));
  assert(explain.description.includes(String(EXPLAIN_PARAGRAPH_MAX_CHARS)));
});
