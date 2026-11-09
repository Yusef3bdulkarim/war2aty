/**
 * F36-T09 · The schema `explain-document`'s model is constrained to.
 *
 * Same split as `analysis-output.schema.ts`, and for the same reason: API
 * CONTRACT §33 describes what the client may receive; this is the GENERATION
 * schema, which a strict structured-output provider accepts. That means no
 * `minLength` / `maxLength` / `pattern` / `format` / `minimum` / `maximum` /
 * `default`, `additionalProperties: false` on every object, and every property
 * listed in `required`, so an optional field is a nullable type instead.
 *
 * Everything this schema cannot express is checked afterwards, and §33's caps
 * are the clearest case: a title of at most 24 characters, paragraphs of at
 * most 220, a page of at most 850. They are stated to the model in the
 * descriptions and the prompt (T10), enforced by T12 — never trusted. Schema-
 * constrained output guarantees SHAPE, never TRUTH or LENGTH.
 *
 * ── What the model is NOT asked for ───────────────────────────────────────
 * - `explain_schema_version` and `session_id` are the envelope, filled in by
 *   the server. Asking a model to echo a session id invites it to invent one.
 * - `paper_type`, `confidence` and `basis` do not exist (§33.2): the approved
 *   design draws none of them, so a model-chosen value nothing reads can only
 *   be wrong.
 * - **`partial` is not a status the model can choose.** `partial` means "the
 *   server removed something it could not ground" (§33.4), which only the
 *   server knows. The model may say `success`, or `unsupported` when the photo
 *   is not a paper this app can explain; T12 raises `success` to `partial`.
 * - No card titles. The app owns every title and icon (§33.3).
 *
 * ── Nullable cards ────────────────────────────────────────────────────────
 * `date`, `caution`, `contact` and `place` are `["object", "null"]`. That is
 * the standard JSON Schema form and what Gemini's `responseJsonSchema` takes,
 * but the existing analysis schema only ever made STRINGS nullable, so no
 * provider in this project has yet been shown to accept a nullable OBJECT in
 * strict mode. **T11 and T18 must measure that per provider** before relying on
 * it: a provider that rejects it answers 4xx, which is `bad_request` and never
 * fails over, so it would be loud rather than silent.
 */

/** §33.1: the header line has to fit one line beside the back arrow and thumbnail. */
export const EXPLAIN_TITLE_MAX_CHARS = 24;

/** §33.3: the most paragraphs `explain` may carry. */
export const EXPLAIN_MAX_PARAGRAPHS = 4;

/** §33.3: the longest single paragraph, in characters. */
export const EXPLAIN_PARAGRAPH_MAX_CHARS = 220;

/**
 * §33.3: the ceiling on every string the voice reads, summed. Measured in
 * F36-T02 at 11.3–12.1 characters a second, so ≈ 75 s of audio.
 */
export const EXPLAIN_PAGE_MAX_CHARS = 850;

/** The JSON Schema sent as `response_format.json_schema.schema`. */
export const EXPLAIN_OUTPUT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["status", "paper", "explain", "todo", "date", "caution", "contact", "place"],
  properties: {
    status: {
      type: "string",
      enum: ["success", "unsupported"],
      description:
        "success when the page was read and explained; unsupported when the photo is not a paper that can be explained (blank, not a document, unreadable). Never anything else.",
    },
    paper: {
      type: "object",
      additionalProperties: false,
      required: ["title"],
      properties: {
        title: {
          type: "string",
          description:
            "Egyptian Arabic, at most 24 characters, no trailing punctuation. Names the paper the way its owner would, e.g. فاتورة الكهربا or عقد إيجار الشقة, not its category.",
        },
      },
    },
    explain: {
      type: "array",
      description:
        "One to four short paragraphs in simple Egyptian Arabic, each at most 220 characters, explaining what the paper is. Never repeats what todo, date, caution, contact or place say.",
      items: { type: "string" },
    },
    todo: {
      type: "object",
      additionalProperties: false,
      required: ["required", "text"],
      properties: {
        required: {
          type: "boolean",
          description: "false when the paper asks nothing of the reader.",
        },
        text: {
          type: "string",
          description:
            "One paragraph saying what to do, including any money or papers to bring. When nothing is asked, say what to do with the paper, e.g. keep it.",
        },
      },
    },
    date: {
      type: ["object", "null"],
      description: "null unless the paper carries a date worth a card.",
      additionalProperties: false,
      required: ["date", "time", "text"],
      properties: {
        date: {
          type: "string",
          description:
            "ISO-8601 date, YYYY-MM-DD, exactly as printed. Never guess a missing year or month.",
        },
        time: {
          type: ["string", "null"],
          description: "HH:mm in 24-hour form, or null when the paper prints no time.",
        },
        text: {
          type: "string",
          description: "What the date is FOR, in a few Egyptian Arabic words. Read aloud.",
        },
      },
    },
    caution: {
      type: ["object", "null"],
      description:
        "null unless the paper carries a real warning. A reminder to keep the paper is not one.",
      additionalProperties: false,
      required: ["text"],
      properties: {
        text: { type: "string", description: "The warning, in simple Egyptian Arabic." },
      },
    },
    contact: {
      type: ["object", "null"],
      description: "null unless a phone number is printed on the paper.",
      additionalProperties: false,
      required: ["name", "phone"],
      properties: {
        name: { type: "string", description: "Who the number belongs to, as the paper says." },
        phone: {
          type: "string",
          description: "Digits only, exactly as printed. Never invented, never completed.",
        },
      },
    },
    place: {
      type: ["object", "null"],
      description: "null unless an address is printed on the paper.",
      additionalProperties: false,
      required: ["text"],
      properties: {
        text: { type: "string", description: "The address, as printed." },
      },
    },
  },
} as const;

/** The `response_format` value for a schema-constrained explanation call. */
export const EXPLAIN_RESPONSE_FORMAT = {
  type: "json_schema" as const,
  json_schema: {
    name: "document_explanation",
    strict: true,
    schema: EXPLAIN_OUTPUT_SCHEMA,
  },
};

// ── the parsed shape ──────────────────────────────────────────────────────

/** What the MODEL may claim. `partial` is the server's (§33.4, T12). */
export type ModelExplainStatus = "success" | "unsupported";

export interface ModelExplainTodo {
  required: boolean;
  text: string;
}

export interface ModelExplainDate {
  date: string;
  time: string | null;
  text: string;
}

export interface ModelExplainCaution {
  text: string;
}

export interface ModelExplainContact {
  name: string;
  phone: string;
}

export interface ModelExplainPlace {
  text: string;
}

/** What the model returns, before grounding, dedupe and the page cap (T12). */
export interface ModelExplanation {
  status: ModelExplainStatus;
  paper: { title: string };
  explain: string[];
  todo: ModelExplainTodo;
  date: ModelExplainDate | null;
  caution: ModelExplainCaution | null;
  contact: ModelExplainContact | null;
  place: ModelExplainPlace | null;
}
