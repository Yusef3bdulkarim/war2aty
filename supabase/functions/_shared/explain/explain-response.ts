/**
 * F36-T15 · Building the explain-document response (§33).
 *
 * The last thing between the model and the device, and the only place that
 * enforces the caps §33 states but the generation schema cannot express:
 * the 24-character title, the 1–4 paragraph count, the 220-character paragraph
 * limit. Grounding (T12) has already run: this file sees only the GROUNDED
 * explanation and never touches the reading (trap #4).
 *
 * ── Why the reading is not in the signature ──────────────────────────────
 * F34 says "Never return the raw OCR text to the phone; use it server-side only
 * to ground phone numbers, amounts and dates." Keeping it out of the builder's
 * INPUT is what keeps it out of the builder's OUTPUT: a future field cannot leak
 * what the function cannot reach. T19 asserts the serialised body contains no
 * substring of the reading.
 *
 * PRIVACY (§7, §51): the report counts what was changed and names field labels
 * only. Nothing here logs or carries document content.
 */

import { ApiError } from "../errors/api-error.ts";
import type { GroundedExplanation, GroundedStatus } from "../validators/explain-grounding.ts";
import {
  EXPLAIN_MAX_PARAGRAPHS,
  EXPLAIN_PARAGRAPH_MAX_CHARS,
  EXPLAIN_TITLE_MAX_CHARS,
} from "../schemas/explain-output.schema.ts";

// ── the §33 wire shape ──────────────────────────────────────────────────

export interface ExplainResponseBody {
  readonly explain_schema_version: string;
  readonly session_id: string;
  readonly status: GroundedStatus;
  readonly paper: { readonly title: string };
  readonly explain: readonly string[];
  readonly todo: { readonly required: boolean; readonly text: string };
  readonly date: {
    readonly date: string;
    readonly time: string | null;
    readonly text: string;
  } | null;
  readonly caution: { readonly text: string } | null;
  readonly contact: { readonly name: string; readonly phone: string } | null;
  readonly place: { readonly text: string } | null;
}

/** What the builder had to fix — counts and booleans only (§51). */
export interface ExplainResponseReport {
  readonly titleTruncated: boolean;
  readonly paragraphsTruncated: number;
  readonly paragraphsDropped: number;
}

export interface BuiltExplainResponse {
  readonly body: ExplainResponseBody;
  readonly report: ExplainResponseReport;
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
 * Turns a grounded explanation into the §33 body.
 *
 * @throws ApiError ANALYSIS_FAILED when the title is blank after trimming — a
 * result screen with no heading is not a usable explanation. This happens inside
 * the reserved slot, so the slot is released and the user is not charged.
 */
export function buildExplainResponse(input: {
  readonly explanation: GroundedExplanation;
  readonly sessionId: string;
  readonly explainSchemaVersion: string;
}): BuiltExplainResponse {
  const { explanation, sessionId, explainSchemaVersion } = input;

  let titleTruncated = false;
  let paragraphsTruncated = 0;
  let paragraphsDropped = 0;

  // ── title ──────────────────────────────────────────────────────────────
  const rawTitle = explanation.paper.title.trim();
  if (rawTitle.length === 0) throw ApiError.analysisFailed();

  let title = rawTitle;
  if (title.length > EXPLAIN_TITLE_MAX_CHARS) {
    title = shorten(title, EXPLAIN_TITLE_MAX_CHARS);
    titleTruncated = true;
  }

  // ── explain paragraphs ─────────────────────────────────────────────────
  let explain = explanation.explain.map((p) => {
    if (p.length > EXPLAIN_PARAGRAPH_MAX_CHARS) {
      paragraphsTruncated++;
      return shorten(p, EXPLAIN_PARAGRAPH_MAX_CHARS);
    }
    return p;
  });

  if (explain.length > EXPLAIN_MAX_PARAGRAPHS) {
    paragraphsDropped = explain.length - EXPLAIN_MAX_PARAGRAPHS;
    explain = explain.slice(0, EXPLAIN_MAX_PARAGRAPHS);
  }

  return {
    body: {
      explain_schema_version: explainSchemaVersion,
      session_id: sessionId,
      status: explanation.status,
      paper: { title },
      explain,
      todo: explanation.todo,
      date: explanation.date,
      caution: explanation.caution,
      contact: explanation.contact,
      place: explanation.place,
    },
    report: {
      titleTruncated,
      paragraphsTruncated,
      paragraphsDropped,
    },
  };
}
