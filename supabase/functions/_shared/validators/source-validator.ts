/**
 * F06-T12 · Source verification (§34).
 *
 * The model labels each fact `extracted` (read from the page) or `inferred`
 * (concluded). This checks the claim rather than trusting it.
 *
 * The asymmetry is deliberate. `extracted` is a strong claim — "this is
 * printed there" — and a false one is how a hallucination reaches the user
 * looking like a fact, so it is verified. `inferred` already tells the user it
 * was reasoning, and the client shows it as such, so it needs no proof.
 */

import type { ModelKeyInformation } from "../schemas/groq-output.schema.ts";
import {
  isIdentifierVerified,
  looksNumeric,
  type VerificationSources,
} from "./number-validator.ts";
import { containsText } from "./text-matching.ts";

/**
 * Whether a fact claimed as `extracted` really appears on the page.
 *
 * Numeric values (account numbers, references) are matched digit-wise so
 * separators do not matter. Textual values are matched as normalised
 * substrings, which tolerates OCR spacing but still catches an invented name.
 *
 * `inferred` values are accepted as-is: the label is the disclosure.
 */
export function isSourceClaimSupported(
  item: ModelKeyInformation,
  sources: VerificationSources,
): boolean {
  if (item.source !== "extracted") return true;

  if (looksNumeric(item.value)) {
    return isIdentifierVerified(item.value, sources);
  }

  if (containsText(sources.ocrText, item.value)) return true;

  // A reference candidate may hold the value in a form the raw text splits
  // across lines.
  return sources.candidates.references.some(
    (candidate) =>
      containsText(candidate.raw_text, item.value) ||
      containsText(candidate.value, item.value),
  );
}
