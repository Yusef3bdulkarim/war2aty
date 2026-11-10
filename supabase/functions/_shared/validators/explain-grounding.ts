/**
 * F36-T12 · Grounding, dedupe and the page cap for an explanation.
 *
 * The schema guarantees the SHAPE of what the model returned. It guarantees
 * neither truth nor length, and this is where both are enforced (§33.3–§33.5):
 *
 * 1. **Labels cleaned.** A model told never to write a heading sometimes still
 *    opens a card with «الشرح:». The app owns every title, so it goes.
 * 2. **Grounding by omission (§33.4).** A phone number, an amount or a date may
 *    appear only if it literally appears in the reading, after digit folding.
 *    An ungrounded value is REMOVED, never downgraded — the new design has no
 *    uncertainty affordance, so a hedge nobody can read would be worse than
 *    silence. Anything removed turns `success` into `partial`.
 * 3. **No repetition (§33.5).** The page is read aloud top to bottom, so a
 *    sentence repeated is heard twice. `explain` loses what another card says;
 *    `caution` loses what `todo` or `date` already said.
 * 4. **The page cap (§33.3).** The sum of every string the voice reads is at
 *    most 850 characters. Over it, the LAST `explain` paragraphs go first —
 *    never `todo`, `date`, `caution` or `contact`, which are what the user acts
 *    on.
 *
 * The checks are the v2 pipeline's own: `isIdentifierVerified`, `isNumberVerified`,
 * `isDateTraceable` and `isTimeSupported`, over `text-matching`'s digit folding.
 * Nothing here re-implements them. They take a `VerificationSources`, whose
 * candidates are empty here: the image path has no on-device extractor, so the
 * reading is the only source (and §33.4 says exactly that).
 *
 * ── What counts as an "amount" or a "phone" in prose ──────────────────────
 * `explain`, `todo`, `caution` and `date.text` are free text, and a model can
 * invent a figure inside a sentence as easily as in a field. Only what is
 * unmistakable is checked: a number beside a currency word, a run of at least
 * seven digits, and a `d/m/yyyy` or `yyyy-mm-dd` date. A bare "4" is a count,
 * not an amount («وفيها 4 أدوية» is the approved prescription line), and a
 * written-out «خمسين جنيه» cannot be checked at all. This is a floor, not a
 * proof — the prompt's rules and T18's golden set are the rest.
 *
 * ── Removal is by SENTENCE ────────────────────────────────────────────────
 * A sentence carrying an ungrounded value is dropped whole: cutting the number
 * out would leave «ادفع جنيه قبل الميعاد», which reads as an instruction.
 * `todo` and `explain` are never null (§33), so if every sentence goes, a fixed
 * line stands in — honest about the gap rather than silent.
 *
 * PRIVACY (§7, §51): the report counts what was changed and never what the
 * page contained. No function here logs anything.
 */

import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import {
  EXPLAIN_PAGE_MAX_CHARS,
  type ModelExplainStatus,
  type ModelExplanation,
} from "../schemas/explain-output.schema.ts";
import { isDateTraceable, isTimeSupported, isWellFormedDate } from "./date-validator.ts";
import {
  isIdentifierVerified,
  isNumberVerified,
  type VerificationSources,
} from "./number-validator.ts";
import { digitsOf, normaliseDigits, normaliseForMatching } from "./text-matching.ts";

/** §33.6: `partial` is the server's word, so the grounded status is wider than the model's. */
export type GroundedStatus = ModelExplainStatus | "partial";

export interface GroundedExplanation extends Omit<ModelExplanation, "status"> {
  status: GroundedStatus;
}

/**
 * What grounding changed. Counts only: the report may be logged, and a log
 * line must never carry a figure from the user's paper (§51).
 */
export interface GroundingReport {
  /** Values removed for not being on the page. These make the status `partial`. */
  readonly ungroundedPhones: number;
  readonly ungroundedAmounts: number;
  readonly ungroundedDates: number;
  readonly ungroundedTimes: number;
  /** Sentences removed because another card already said them. */
  readonly duplicateSentences: number;
  /** Cards that opened with a heading the app owns. */
  readonly labelsCleaned: number;
  /** `explain` paragraphs dropped to fit the page cap. */
  readonly paragraphsTrimmed: number;
  /** False when the page still exceeds the cap with nothing left to trim. T15 decides. */
  readonly fitsPage: boolean;
}

export interface GroundingResult {
  readonly explanation: GroundedExplanation;
  readonly report: GroundingReport;
}

/**
 * Stand-ins for a `todo` or `explain` that grounding emptied. Both are never
 * null (§33), and a blank card would be read aloud as silence.
 */
export const EMPTY_TODO_TEXT = "راجع الورقة نفسها عشان تعرف المطلوب منك بالظبط.";
export const EMPTY_EXPLAIN_TEXT = "دي ورقة ومقدرتش أتأكد من كل المعلومات اللي فيها.";

const NO_CANDIDATES: ExtractedCandidates = {
  dates: [],
  times: [],
  amounts: [],
  phones: [],
  references: [],
};

// ── sentences ─────────────────────────────────────────────────────────────

/** Splits on sentence-final punctuation followed by space, and on newlines. */
function splitSentences(text: string): string[] {
  return text.split(/(?<=[.!?؟…])\s+|\n+/).map((s) => s.trim()).filter((s) => s.length > 0);
}

/** Two sentences are "the same" when only spacing and punctuation differ. */
function sentenceKey(sentence: string): string {
  return normaliseForMatching(sentence)
    .replaceAll(/[.!?؟،,:;…"'«»()\-–—*#]/g, "")
    .replaceAll(/\s+/g, " ")
    .trim();
}

const join = (sentences: readonly string[]) => sentences.join(" ");

// ── labels ────────────────────────────────────────────────────────────────

/**
 * The headings the app draws itself (§33.3), plus the stray markdown a model
 * adds to a heading. Anchored to the start: a colon mid-sentence is prose.
 */
const LABEL = new RegExp(
  "^[\\s*#>\\-–—]*(?:الشرح|شرح الورقة|المطلوب|اعمل إيه|أعمل إيه|اعمل ايه|أعمل ايه|ميعاد|الميعاد|" +
    "خلي بالك|تنبيه|تحذير|ملاحظة|تكلم مين|تروح فين|العنوان|المكان)\\s*[:：]\\s*",
);

function cleanLabel(text: string, onClean: () => void): string {
  const cleaned = text.replace(LABEL, "").replaceAll("**", "").trim();
  if (cleaned !== text.trim()) onClean();
  return cleaned;
}

// ── grounding of values inside prose ──────────────────────────────────────

const CURRENCY = "(?:جنيه|جنية|ج\\.م|EGP|L\\.E\\.?|LE)";
const NUMBER = "\\d[\\d,]*(?:\\.\\d+)?";
const AMOUNT_AFTER = new RegExp(`(${NUMBER})\\s*${CURRENCY}`, "gi");
const AMOUNT_BEFORE = new RegExp(`${CURRENCY}\\s*(${NUMBER})`, "gi");
const PHONE_LIKE = /\+?\d(?:[\s-]?\d){6,}/g;
const DATE_LIKE = /\b(\d{1,4})[/-](\d{1,2})[/-](\d{1,4})\b/g;

type ProseKind = "phone" | "amount" | "date";

/** The kinds of unverifiable value found in a sentence, none when it is clean. */
function ungroundedIn(sentence: string, sources: VerificationSources): ProseKind[] {
  const text = normaliseForMatching(sentence);
  const found = new Set<ProseKind>();

  for (const pattern of [AMOUNT_AFTER, AMOUNT_BEFORE]) {
    for (const match of text.matchAll(pattern)) {
      const value = Number(match[1].replaceAll(",", ""));
      if (!isNumberVerified(value, sources)) found.add("amount");
    }
  }

  const digits = normaliseDigits(sentence);

  // Dates are blanked first: "2026-11-20" is eight digits with separators, and
  // would otherwise be tested as a phone against a page that prints it
  // day-first, dropping a date that IS on the paper.
  for (const match of digits.replaceAll(DATE_LIKE, " ").matchAll(PHONE_LIKE)) {
    if (!isIdentifierVerified(match[0], sources)) found.add("phone");
  }

  for (const match of digits.matchAll(DATE_LIKE)) {
    // Year-first when the first part is four digits, day-first otherwise: how
    // an Egyptian paper writes it. `isDateTraceable` only asks that each part
    // be on the page, so a swapped day and month cannot cause a false drop.
    const [, a, b, c] = match;
    const iso = a.length === 4
      ? `${a}-${b.padStart(2, "0")}-${c.padStart(2, "0")}`
      : `${c}-${b.padStart(2, "0")}-${a.padStart(2, "0")}`;
    if (!isWellFormedDate(iso) || !isDateTraceable(iso, sources)) found.add("date");
  }

  return [...found];
}

// ── the page ──────────────────────────────────────────────────────────────

/** Every string the voice reads, summed (§33.3). */
export function pageLength(explanation: Omit<ModelExplanation, "status">): number {
  const strings = [
    explanation.paper.title,
    ...explanation.explain,
    explanation.todo.text,
    explanation.date?.text ?? "",
    explanation.caution?.text ?? "",
    explanation.contact?.name ?? "",
    explanation.place?.text ?? "",
  ];
  return strings.reduce((sum, s) => sum + s.length, 0);
}

/**
 * Grounds, dedupes and caps one explanation against the reading.
 *
 * `unsupported` is returned untouched: the slot is released and nothing is
 * shown, so there is nothing to ground.
 */
export function groundExplanation(model: ModelExplanation, reading: string): GroundingResult {
  const sources: VerificationSources = { ocrText: reading, candidates: NO_CANDIDATES };

  let ungroundedPhones = 0;
  let ungroundedAmounts = 0;
  let ungroundedDates = 0;
  let ungroundedTimes = 0;
  let duplicateSentences = 0;
  let labelsCleaned = 0;
  const onLabel = () => labelsCleaned++;

  if (model.status === "unsupported") {
    return {
      explanation: model,
      report: {
        ungroundedPhones,
        ungroundedAmounts,
        ungroundedDates,
        ungroundedTimes,
        duplicateSentences,
        labelsCleaned,
        paragraphsTrimmed: 0,
        fitsPage: true,
      },
    };
  }

  /** Drops sentences carrying an ungrounded value, counting each kind once per sentence. */
  const ground = (text: string): string => {
    const kept: string[] = [];
    for (const sentence of splitSentences(text)) {
      const kinds = ungroundedIn(sentence, sources);
      if (kinds.length === 0) {
        kept.push(sentence);
        continue;
      }
      if (kinds.includes("phone")) ungroundedPhones++;
      if (kinds.includes("amount")) ungroundedAmounts++;
      if (kinds.includes("date")) ungroundedDates++;
    }
    return join(kept);
  };

  const clean = (text: string) => ground(cleanLabel(text, onLabel));

  // ── the cards ───────────────────────────────────────────────────────────
  let explain = model.explain.map(clean).filter((p) => p.length > 0);
  const todoText = clean(model.todo.text);
  const todo = { required: model.todo.required, text: todoText || EMPTY_TODO_TEXT };

  let date = model.date;
  if (date !== null) {
    const wellFormed = isWellFormedDate(date.date);
    if (!wellFormed || !isDateTraceable(date.date, sources)) {
      // The whole card goes: a date nobody can find on the page is the most
      // damaging thing this endpoint could say, and `date` is nullable for it.
      ungroundedDates++;
      date = null;
    } else {
      // A time the page does not print is dropped alone; the date itself stands.
      let time = date.time;
      if (time !== null && !isTimeSupported(time, sources)) {
        ungroundedTimes++;
        time = null;
      }
      date = { date: date.date, time, text: clean(date.text) };
    }
  }

  let caution = model.caution === null ? null : { text: clean(model.caution.text) };
  if (caution !== null && caution.text.length === 0) caution = null;

  let contact = model.contact;
  if (contact !== null) {
    const phone = digitsOf(contact.phone);
    // `isIdentifierVerified` is a digit-sequence test, so «٠١٠…» on the page
    // matches "010…" from the model.
    if (phone.length === 0 || !isIdentifierVerified(phone, sources)) {
      ungroundedPhones++;
      contact = null;
    } else {
      contact = { name: contact.name, phone };
    }
  }

  // `place` is an address "as printed": OCR spacing makes a literal match
  // unreliable, so it is passed through, as the contract's validators do for
  // names and labels.
  const place = model.place;

  // ── no repetition ───────────────────────────────────────────────────────
  // What the action cards say is kept where it is; the repeat is removed from
  // the card that is only describing it.
  const claimed = new Set<string>();
  const claim = (text: string | undefined) => {
    for (const s of splitSentences(text ?? "")) claimed.add(sentenceKey(s));
  };
  claim(todo.text);
  claim(date?.text);

  const withoutRepeats = (text: string, seen: Set<string>): string => {
    const kept: string[] = [];
    for (const sentence of splitSentences(text)) {
      const key = sentenceKey(sentence);
      if (key.length > 0 && seen.has(key)) {
        duplicateSentences++;
        continue;
      }
      seen.add(key);
      kept.push(sentence);
    }
    return join(kept);
  };

  if (caution !== null) {
    const text = withoutRepeats(caution.text, claimed);
    caution = text.length === 0 ? null : { text };
  }
  claim(caution?.text);
  claim(contact?.name);
  claim(place?.text);

  // Duplicates are matched across `explain` as well as against the cards, so
  // the set is shared and filled as the paragraphs are walked.
  explain = explain.map((p) => withoutRepeats(p, claimed)).filter((p) => p.length > 0);
  if (explain.length === 0) explain = [EMPTY_EXPLAIN_TEXT];

  // ── the page cap ────────────────────────────────────────────────────────
  const build = (): Omit<ModelExplanation, "status"> => ({
    paper: model.paper,
    explain,
    todo,
    date,
    caution,
    contact,
    place,
  });

  let paragraphsTrimmed = 0;
  while (pageLength(build()) > EXPLAIN_PAGE_MAX_CHARS && explain.length > 1) {
    explain = explain.slice(0, -1);
    paragraphsTrimmed++;
  }

  const ungrounded = ungroundedPhones + ungroundedAmounts + ungroundedDates + ungroundedTimes;
  const built = build();

  return {
    explanation: { ...built, status: ungrounded > 0 ? "partial" : model.status },
    report: {
      ungroundedPhones,
      ungroundedAmounts,
      ungroundedDates,
      ungroundedTimes,
      duplicateSentences,
      labelsCleaned,
      paragraphsTrimmed,
      fitsPage: pageLength(built) <= EXPLAIN_PAGE_MAX_CHARS,
    },
  };
}
