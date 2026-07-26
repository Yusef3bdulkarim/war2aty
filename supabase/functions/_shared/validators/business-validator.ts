/**
 * F06-T12 · Business and safety rules (§34).
 *
 * These are the checks that need product knowledge rather than string
 * matching: what a value means, and what the user must be told alongside it.
 */

import type {
  ModelAmount,
  ModelAnalysis,
  ModelDate,
  ModelWarning,
} from "../schemas/groq-output.schema.ts";

/**
 * An amount must be a real, non-negative number.
 *
 * A negative total on a bill is not a discount the user should act on — it is
 * a misread minus sign or a stray dash from the page layout.
 */
export function isPlausibleAmount(amount: ModelAmount): boolean {
  return Number.isFinite(amount.value) && amount.value >= 0;
}

/**
 * Whether a date may drive a reminder.
 *
 * A past date cannot: scheduling a notification for a moment that has gone is
 * pure noise, and F09 would silently drop it anyway. `issued` and `period_*`
 * dates are facts about the document, not things to be reminded of.
 */
export function mayDriveReminder(date: ModelDate, inPast: boolean): boolean {
  if (inPast) return false;
  return date.role === "deadline" || date.role === "appointment" ||
    date.role === "expiry" || date.role === "event";
}

/**
 * The warning a document type must carry (§7, §30.3), or null.
 *
 * These are non-negotiable product requirements, not the model's judgement: a
 * medical report must never be presented without saying it is no substitute
 * for a doctor. Relying on the model to remember is exactly the kind of thing
 * it will do nine times out of ten.
 */
export function requiredWarningFor(
  documentType: string,
): ModelWarning | null {
  switch (documentType) {
    case "medical":
      return {
        text: "التقرير ده مش بديل عن استشارة الدكتور. راجع طبيبك.",
        type: "medical",
      };
    case "legal":
      return {
        text: "استشر محامي قبل ما تاخد أي إجراء قانوني.",
        type: "legal",
      };
    case "government":
      return {
        text: "تأكد من البيانات من الجهة الرسمية نفسها.",
        type: "government",
      };
    case "financial":
      return {
        text: "راجع البنك أو الجهة المالية للتأكيد.",
        type: "financial",
      };
    default:
      return null;
  }
}

/** Whether the analysis already carries a warning of that type. */
export function hasWarningOfType(
  analysis: ModelAnalysis,
  type: ModelWarning["type"],
): boolean {
  return analysis.warnings.some((warning) => warning.type === type);
}

/**
 * Whether an `unsupported` result is claiming to have read things.
 *
 * "I could not read this" and "here are seven confident facts from it" cannot
 * both be true; the client shows an OCR-only fallback for `unsupported` and
 * would hide the facts anyway.
 */
export function isContradictoryUnsupported(analysis: ModelAnalysis): boolean {
  if (analysis.status !== "unsupported") return false;
  return analysis.key_information.length > 0 ||
    analysis.dates.length > 0 ||
    analysis.amounts.length > 0;
}
