/**
 * F36-T13 · The interim prescription / lab path (F34-T13).
 *
 * With `paper_type` gone (§33.2), a prescription or a lab result is an ordinary
 * paper as far as the wire is concerned. What makes it different is a promise
 * the app must keep without a model's cooperation: **it never says what a drug
 * is for or how to take it, and never says what a lab value means.** The prompt
 * asks (T10); this file is what makes the asking not matter, because a prompt
 * is a request and a user acts on the answer.
 *
 * Two deterministic steps, both applied by `groundExplanation` and both only
 * when the READING says the paper is medical:
 *
 * 1. **Claims are removed, by sentence.** A sentence carrying a dose, a dosing
 *    schedule or a verdict on a result («طبيعي», «مرتفع») is dropped. It is
 *    not counted as ungrounded and does not make the status `partial`: the
 *    sentence may well be on the page, it is simply not ours to say.
 * 2. **The referral is guaranteed.** F34's interim lines send the user to the
 *    right person: the pharmacist reads the drugs, the doctor explains the
 *    result. If `todo` does not already say so, the fixed line is appended —
 *    so the app's behaviour does not depend on the model remembering.
 *
 * ── Detection is from the reading, not from the model ─────────────────────
 * A model-chosen paper kind is exactly what §33.2 deleted, and trusting it here
 * would let the model switch the safeguard off. The keyword lists are narrow on
 * purpose: a wrong "medical" costs a few good sentences on an ordinary paper,
 * a missed one costs a drug instruction. A prescription wins over a lab result
 * when both are present, because a prescription may mention tests.
 *
 * ── A floor, not a proof ──────────────────────────────────────────────────
 * Drug NAMES cannot be recognised without a drug list (the full version, F34's
 * "after the last version", checks Egypt's registry). What is caught is what has
 * a recognisable shape: quantities with a unit, schedules, verdict words.
 *
 * PRIVACY (§7, §51): pure functions over strings; nothing is logged or retained.
 */

export type MedicalPaper = "prescription" | "lab";

/** F34's interim lines, in the voice the owner approved. */
export const PRESCRIPTION_REFERRAL = "خلي الصيدلي يقرالك الأدوية ومواعيدها.";
export const LAB_REFERRAL = "وري النتيجة لدكتورك عشان يشرحهالك.";

const PRESCRIPTION_WORDS = /روشتة|روشته|تذكرة طبية|تذكره طبيه|\bRx\b|prescription/i;
const LAB_WORDS =
  /تحاليل|تحليل دم|تحليل بول|معمل|مختبر|laborator|reference range|\bCBC\b|hemoglobin|هيموجلوبين|كوليسترول/i;

/** Which medical paper the reading is, or `null` for any other paper. */
export function detectMedicalPaper(reading: string): MedicalPaper | null {
  if (PRESCRIPTION_WORDS.test(reading)) return "prescription";
  if (LAB_WORDS.test(reading)) return "lab";
  return null;
}

const UNIT = "(?:mg|mcg|ml|g|iu|ملجم|مجم|ملغ|ملليجرام|مللي|مل|جرام|وحدة|وحدات|قرص|أقراص|اقراص|" +
  "حبة|حبايه|حبوب|كبسولة|كبسولات|نقطة|نقط|ملعقة|أمبول|امبول|حقنة)";
const DOSE = new RegExp(`\\d+(?:[.,]\\d+)?\\s*${UNIT}(?![\\p{L}])`, "iu");
const SCHEDULE =
  /(?:مرة|مرتين|ثلاث مرات|تلات مرات|\d+ مرات?)\s*(?:في|ف)\s*(?:ال)?(?:يوم|اليوم|اسبوع|الأسبوع)|قبل الأكل|بعد الأكل|على الريق|كل\s*\d+\s*ساعات?/;
const VERDICT =
  /غير طبيعي|طبيعي|مرتفع|منخفض|عالي|واطي|ارتفاع|انخفاض|نقص في|زيادة في|تشخيص|التهاب|سكر|ضغط|سرطان|فقر دم|أنيميا/;

/** Whether a sentence states a dose, a schedule or a verdict. */
export function makesMedicalClaim(sentence: string): boolean {
  return DOSE.test(sentence) || SCHEDULE.test(sentence) || VERDICT.test(sentence);
}

/** Whether `todo` already sends the user to the right person. */
export function hasReferral(kind: MedicalPaper, todoText: string): boolean {
  return kind === "prescription" ? /صيدلي/.test(todoText) : /دكتور|طبيب|دكتورك/.test(todoText);
}

export function referralFor(kind: MedicalPaper): string {
  return kind === "prescription" ? PRESCRIPTION_REFERRAL : LAB_REFERRAL;
}
