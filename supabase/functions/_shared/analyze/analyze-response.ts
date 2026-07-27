/**
 * F06-T13 · Building the analyze-document response (§30).
 *
 * The last thing between the model and the device, and the only place that
 * enforces the constraints §30 has but Groq's schema subset cannot express:
 * `minLength`, `maxLength`, `format: date`, the `HH:mm` pattern.
 *
 * ── Why this is not merely defensive ─────────────────────────────────────
 * The client's mapper THROWS on a `dates[].date` it cannot parse and on an
 * unknown `dates[].role` (`analysis_response_mapper.dart`), and the repository
 * turns that into `InvalidAnalysisResponseFailure` — for the WHOLE response.
 * So one date the model wrote as "next Tuesday" would destroy an otherwise
 * perfect analysis of someone's electricity bill on their phone.
 *
 * Dropping that one date instead is strictly better: everything else survives,
 * the field is named in `missing_fields`, and the status falls to `partial` so
 * the result screen shows its review banner. The user is told something is
 * missing rather than told nothing at all.
 *
 * Enum values that the client already falls back on (`confidence`, `source`,
 * `basis`, `priority`, `warnings[].type`, `document_type.type`) are coerced to
 * the same cautious default it would pick, so the body still satisfies §30's
 * closed enums.
 *
 * PRIVACY: the report counts and names fields. It never carries a value.
 */

import type { AnalysisStatus, Confidence, ModelAnalysis } from "../schemas/groq-output.schema.ts";
import { ApiError } from "../errors/api-error.ts";
import { isWellFormedDate, isWellFormedTime } from "../validators/date-validator.ts";

// ── the §30 wire shape ────────────────────────────────────────────────────

export interface ResponseDocumentType {
  readonly type: string;
  readonly title: string;
  readonly confidence: Confidence;
}

export interface ResponseSummary {
  readonly short: string;
  readonly detailed: string;
}

export interface ResponseKeyInfo {
  readonly label: string;
  readonly value: string;
  readonly confidence: Confidence;
  readonly source: "extracted" | "inferred";
}

export interface ResponseDate {
  readonly label: string;
  readonly date: string;
  readonly time: string | null;
  readonly role: string;
  readonly is_reminder_worthy: boolean;
  readonly confidence: Confidence;
}

export interface ResponseAmount {
  readonly label: string;
  readonly value: number;
  readonly currency: string;
  readonly confidence: Confidence;
}

export interface ResponseAction {
  readonly description: string;
  readonly basis: "explicit" | "inferred";
  readonly priority: "high" | "normal";
}

export interface ResponseWarning {
  readonly text: string;
  readonly type: "medical" | "legal" | "government" | "financial" | "general";
}

export interface AnalysisResponseBody {
  readonly schema_version: string;
  readonly session_id: string;
  readonly status: AnalysisStatus;
  readonly document_type: ResponseDocumentType;
  readonly summary: ResponseSummary;
  readonly key_information: ResponseKeyInfo[];
  readonly dates: ResponseDate[];
  readonly amounts: ResponseAmount[];
  readonly actions_required: ResponseAction[];
  readonly required_documents: string[];
  readonly instructions: string[];
  readonly warnings: ResponseWarning[];
  readonly missing_fields: string[];
}

/** What had to be discarded to satisfy §30. Field names and counts only. */
export interface ResponseReport {
  /** Contract field names whose items were partly dropped. */
  readonly dropped: string[];
  readonly droppedItems: number;
  readonly truncatedSummary: boolean;
  readonly statusChanged: boolean;
}

export interface BuiltAnalysisResponse {
  readonly body: AnalysisResponseBody;
  readonly report: ResponseReport;
}

// ── §30 enums, and the fallback the client would have chosen anyway ───────

const DOCUMENT_TYPES: ReadonlySet<string> = new Set([
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

const DATE_ROLES: ReadonlySet<string> = new Set([
  "deadline",
  "appointment",
  "issued",
  "expiry",
  "event",
  "period_start",
  "period_end",
]);

const WARNING_TYPES: ReadonlySet<string> = new Set([
  "medical",
  "legal",
  "government",
  "financial",
  "general",
]);

const CONFIDENCES: ReadonlySet<string> = new Set(["high", "medium", "low"]);

/** §30 caps `summary.short` at 200; `detailed` still carries the full text. */
const MAX_SHORT_SUMMARY = 200;

/** Unknown reads as `low`, so the value shows as «قراءة غير مؤكدة», not fact. */
function confidence(value: string): Confidence {
  return CONFIDENCES.has(value) ? value as Confidence : "low";
}

function trimmed(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** Truncates on a word boundary where there is one, so the sentence still reads. */
function shorten(value: string, limit: number): string {
  if (value.length <= limit) return value;

  const clipped = value.slice(0, limit - 1);
  const lastSpace = clipped.lastIndexOf(" ");
  const base = lastSpace > limit / 2 ? clipped.slice(0, lastSpace) : clipped;
  return `${base}…`;
}

/**
 * Turns a validated analysis into the §30 body.
 *
 * @throws ApiError ANALYSIS_FAILED when the model returned nothing displayable
 * — a blank title or a blank summary. Failing here (inside the reserved slot,
 * so it is released) is right: a result screen with no heading and no
 * explanation is not an analysis, and charging a user for one would be worse
 * than telling them it failed.
 */
export function buildAnalysisResponse(input: {
  readonly analysis: ModelAnalysis;
  readonly sessionId: string;
  readonly schemaVersion: string;
}): BuiltAnalysisResponse {
  const { analysis, sessionId, schemaVersion } = input;

  const dropped: string[] = [];
  let droppedItems = 0;

  const note = (field: string, count: number) => {
    if (count === 0) return;
    droppedItems += count;
    if (!dropped.includes(field)) dropped.push(field);
  };

  // ── document type & summary: required, so a blank one is fatal ──────────
  const title = trimmed(analysis.document_type.title);
  const short = trimmed(analysis.summary.short);
  const detailed = trimmed(analysis.summary.detailed);
  if (title.length === 0 || short.length === 0 || detailed.length === 0) {
    throw ApiError.analysisFailed();
  }

  const documentType: ResponseDocumentType = {
    type: DOCUMENT_TYPES.has(analysis.document_type.type) ? analysis.document_type.type : "other",
    title,
    confidence: confidence(analysis.document_type.confidence),
  };

  const summary: ResponseSummary = {
    short: shorten(short, MAX_SHORT_SUMMARY),
    detailed,
  };

  // ── collections: keep what §30 accepts, name what was lost ─────────────
  const keyInformation: ResponseKeyInfo[] = [];
  for (const item of analysis.key_information) {
    const label = trimmed(item.label);
    const value = trimmed(item.value);
    if (label.length === 0 || value.length === 0) continue;

    keyInformation.push({
      label,
      value,
      confidence: confidence(item.confidence),
      source: item.source === "extracted" ? "extracted" : "inferred",
    });
  }
  note("key_information", analysis.key_information.length - keyInformation.length);

  const dates: ResponseDate[] = [];
  for (const item of analysis.dates) {
    const label = trimmed(item.label);
    // A date the client cannot parse, or a role it does not know, would make it
    // throw away the entire response — see the header comment.
    if (label.length === 0 || !isWellFormedDate(item.date) || !DATE_ROLES.has(item.role)) {
      continue;
    }

    const time = typeof item.time === "string" && isWellFormedTime(item.time) ? item.time : null;

    dates.push({
      label,
      date: item.date,
      time,
      role: item.role,
      // Coerced rather than trusted: anything that is not exactly `true` must
      // not end up scheduling a notification in F09.
      is_reminder_worthy: item.is_reminder_worthy === true,
      confidence: confidence(item.confidence),
    });
  }
  note("dates", analysis.dates.length - dates.length);

  const amounts: ResponseAmount[] = [];
  for (const item of analysis.amounts) {
    const label = trimmed(item.label);
    const currency = trimmed(item.currency);
    // §30 requires a currency. Defaulting one would be inventing a fact about
    // someone's money, so an amount without it is dropped instead.
    if (label.length === 0 || currency.length === 0) continue;
    if (typeof item.value !== "number" || !Number.isFinite(item.value)) continue;

    amounts.push({
      label,
      value: item.value,
      currency,
      confidence: confidence(item.confidence),
    });
  }
  note("amounts", analysis.amounts.length - amounts.length);

  const actions: ResponseAction[] = [];
  for (const item of analysis.actions_required) {
    const description = trimmed(item.description);
    if (description.length === 0) continue;

    actions.push({
      description,
      basis: item.basis === "explicit" ? "explicit" : "inferred",
      priority: item.priority === "high" ? "high" : "normal",
    });
  }
  note("actions_required", analysis.actions_required.length - actions.length);

  const requiredDocuments = analysis.required_documents.map(trimmed).filter((
    value,
  ) => value.length > 0);
  note(
    "required_documents",
    analysis.required_documents.length - requiredDocuments.length,
  );

  const instructions = analysis.instructions.map(trimmed).filter((value) => value.length > 0);
  note("instructions", analysis.instructions.length - instructions.length);

  const warnings: ResponseWarning[] = [];
  for (const item of analysis.warnings) {
    const text = trimmed(item.text);
    if (text.length === 0) continue;

    warnings.push({
      text,
      type: WARNING_TYPES.has(item.type) ? item.type : "general",
    });
  }
  note("warnings", analysis.warnings.length - warnings.length);

  const missingFields = Array.from(
    new Set([
      ...analysis.missing_fields.map(trimmed).filter((value) => value.length > 0),
      ...dropped,
    ]),
  );

  // A `success` that quietly lost fields would render without the review
  // banner, which is precisely the case the banner exists for.
  const status: AnalysisStatus = analysis.status === "success" && missingFields.length > 0
    ? "partial"
    : analysis.status;

  return {
    body: {
      schema_version: schemaVersion,
      session_id: sessionId,
      status,
      document_type: documentType,
      summary,
      key_information: keyInformation,
      dates,
      amounts,
      actions_required: actions,
      required_documents: requiredDocuments,
      instructions,
      warnings,
      missing_fields: missingFields,
    },
    report: {
      dropped,
      droppedItems,
      truncatedSummary: summary.short !== short,
      statusChanged: status !== analysis.status,
    },
  };
}
