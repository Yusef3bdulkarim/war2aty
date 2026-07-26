/**
 * F06-T11 · The schema the model is constrained to.
 *
 * ── Why this is not API_CONTRACT §30 verbatim ────────────────────────────
 * Two different jobs need two different schemas.
 *
 * §30 is the CONTRACT: draft-07, with `minLength`, `format`, `maxLength` and
 * `default`. It describes what the client may receive, and F06-T12 validates
 * against its rules.
 *
 * This is the GENERATION schema. Groq's strict structured output accepts only
 * a narrow subset — no `minLength`, `maxLength`, `pattern`, `format`,
 * `minimum`, `maximum` or `default`; every object needs
 * `additionalProperties: false`; every property must appear in `required`, so
 * an optional field is expressed as a nullable type instead. Sending §30 as-is
 * is rejected.
 *
 * Everything the generation schema cannot express — a date really being a
 * date, a summary being non-empty, an amount matching the page — is checked
 * afterwards by the validation pipeline. Schema-constrained output guarantees
 * SHAPE, never TRUTH.
 *
 * ── Fields the model is not asked for ────────────────────────────────────
 * `schema_version` and `session_id` are filled in by the server. Asking the
 * model to echo a session id invites it to invent one, and a hallucinated id
 * would attach an analysis to the wrong document.
 */

const CONFIDENCE = {
  type: "string",
  enum: ["high", "medium", "low"],
} as const;

/** The JSON Schema sent as `response_format.json_schema.schema`. */
export const GROQ_OUTPUT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "status",
    "document_type",
    "summary",
    "key_information",
    "dates",
    "amounts",
    "actions_required",
    "required_documents",
    "instructions",
    "warnings",
    "missing_fields",
  ],
  properties: {
    status: {
      type: "string",
      enum: ["success", "partial", "unsupported"],
      description:
        "success when the document was fully read; partial when some fields could not be resolved; unsupported when the text is too damaged or the document type is out of scope.",
    },
    document_type: {
      type: "object",
      additionalProperties: false,
      required: ["type", "title", "confidence"],
      properties: {
        type: {
          type: "string",
          enum: [
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
          ],
        },
        title: {
          type: "string",
          description: "Short Arabic title for the document, e.g. فاتورة كهرباء.",
        },
        confidence: CONFIDENCE,
      },
    },
    summary: {
      type: "object",
      additionalProperties: false,
      required: ["short", "detailed"],
      properties: {
        short: {
          type: "string",
          description: "One sentence in simple Egyptian Arabic. Under 200 characters.",
        },
        detailed: {
          type: "string",
          description:
            "A few sentences in simple Egyptian Arabic explaining what the paper is and what it asks of the reader.",
        },
      },
    },
    key_information: {
      type: "array",
      description:
        "Facts read from the document: account numbers, references, names of the issuing body.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["label", "value", "confidence", "source"],
        properties: {
          label: { type: "string", description: "Arabic label, e.g. رقم الحساب." },
          value: {
            type: "string",
            description: "The value exactly as printed. Never reformatted, never invented.",
          },
          confidence: CONFIDENCE,
          source: {
            type: "string",
            enum: ["extracted", "inferred"],
            description: "extracted when read directly from the text; inferred when concluded.",
          },
        },
      },
    },
    dates: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["label", "date", "time", "role", "is_reminder_worthy", "confidence"],
        properties: {
          label: { type: "string", description: "Arabic label, e.g. آخر موعد للسداد." },
          date: {
            type: "string",
            description:
              "ISO-8601 date, YYYY-MM-DD. Never guess a missing year: if the year is absent or the reading is uncertain, set confidence to low.",
          },
          time: {
            type: ["string", "null"],
            description:
              "HH:mm in 24-hour form, or null when the document states no time. Never invent one.",
          },
          role: {
            type: "string",
            enum: [
              "deadline",
              "appointment",
              "issued",
              "expiry",
              "event",
              "period_start",
              "period_end",
            ],
          },
          is_reminder_worthy: {
            type: "boolean",
            description:
              "true only when the document itself makes this a deadline or appointment the reader must act on.",
          },
          confidence: CONFIDENCE,
        },
      },
    },
    amounts: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["label", "value", "currency", "confidence"],
        properties: {
          label: { type: "string", description: "Arabic label, e.g. إجمالي المبلغ." },
          value: {
            type: "number",
            description: "The amount exactly as printed. Never computed, never rounded.",
          },
          currency: { type: "string", description: "As written, e.g. جنيه or EGP." },
          confidence: CONFIDENCE,
        },
      },
    },
    actions_required: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["description", "basis", "priority"],
        properties: {
          description: {
            type: "string",
            description: "What the reader must do, in simple Egyptian Arabic.",
          },
          basis: {
            type: "string",
            enum: ["explicit", "inferred"],
            description: "explicit when the document says so; inferred when concluded.",
          },
          priority: { type: "string", enum: ["high", "normal"] },
        },
      },
    },
    required_documents: {
      type: "array",
      description: "Papers the reader must bring, in Arabic. Only if the document says so.",
      items: { type: "string" },
    },
    instructions: {
      type: "array",
      description: "Steps stated by the document, in simple Egyptian Arabic.",
      items: { type: "string" },
    },
    warnings: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["text", "type"],
        properties: {
          text: { type: "string", description: "Arabic warning text." },
          type: {
            type: "string",
            enum: ["medical", "legal", "government", "financial", "general"],
          },
        },
      },
    },
    missing_fields: {
      type: "array",
      description: "Names of fields that could not be resolved. Empty when status is success.",
      items: { type: "string" },
    },
  },
} as const;

/** The `response_format` value for a schema-constrained analysis call. */
export const GROQ_ANALYSIS_RESPONSE_FORMAT = {
  type: "json_schema" as const,
  json_schema: {
    name: "document_analysis",
    strict: true,
    schema: GROQ_OUTPUT_SCHEMA,
  },
};

// ── the parsed shape ──────────────────────────────────────────────────────

export type Confidence = "high" | "medium" | "low";
export type AnalysisStatus = "success" | "partial" | "unsupported";

export interface ModelDocumentType {
  type: string;
  title: string;
  confidence: Confidence;
}

export interface ModelSummary {
  short: string;
  detailed: string;
}

export interface ModelKeyInformation {
  label: string;
  value: string;
  confidence: Confidence;
  source: "extracted" | "inferred";
}

export interface ModelDate {
  label: string;
  date: string;
  time: string | null;
  role: string;
  is_reminder_worthy: boolean;
  confidence: Confidence;
}

export interface ModelAmount {
  label: string;
  value: number;
  currency: string;
  confidence: Confidence;
}

export interface ModelAction {
  description: string;
  basis: "explicit" | "inferred";
  priority: "high" | "normal";
}

export interface ModelWarning {
  text: string;
  type: "medical" | "legal" | "government" | "financial" | "general";
}

/** What the model returns, before the validation pipeline (F06-T12). */
export interface ModelAnalysis {
  status: AnalysisStatus;
  document_type: ModelDocumentType;
  summary: ModelSummary;
  key_information: ModelKeyInformation[];
  dates: ModelDate[];
  amounts: ModelAmount[];
  actions_required: ModelAction[];
  required_documents: string[];
  instructions: string[];
  warnings: ModelWarning[];
  missing_fields: string[];
}
