/**
 * F36-T13 · The interim prescription / lab path, one test group per paper type.
 *
 * Each group drives the REAL pipeline — `assertModelExplanation` for the shape,
 * `groundExplanation` for what survives — with a model answer and the reading
 * it came from. The negative cases are what matter: a model that ignores the
 * prompt and states a dose or a verdict must not get that sentence to the user.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { assertModelExplanation } from "../../functions/_shared/ai/explain-chain.ts";
import {
  detectMedicalPaper,
  hasReferral,
  LAB_REFERRAL,
  makesMedicalClaim,
  PRESCRIPTION_REFERRAL,
} from "../../functions/_shared/validators/explain-medical.ts";
import { groundExplanation } from "../../functions/_shared/validators/explain-grounding.ts";
import type { ModelExplanation } from "../../functions/_shared/schemas/explain-output.schema.ts";

const PRESCRIPTION_READING = [
  "روشتة طبية",
  "د. أحمد سمير - استشاري الباطنة",
  "التاريخ: 12/11/2026",
  "1. Augmentin 1g tablet - مرتين في اليوم",
  "2. Panadol 500 mg",
  "3. Nexium 40 mg",
  "4. Zyrtec",
].join("\n");

const LAB_READING = [
  "معمل الأمل للتحاليل الطبية",
  "التاريخ: 8/11/2026",
  "Hemoglobin 10.2 g/dL (reference range 12-16)",
  "Glucose 165 mg/dL",
].join("\n");

const NO_FIELDS = { caution: null, contact: null, place: null } as const;

/** What the interim rules want a model to write for a prescription. */
const GOOD_PRESCRIPTION: ModelExplanation = {
  status: "success",
  paper: { title: "روشتة د. أحمد سمير" },
  explain: ["دي روشتة من دكتور أحمد سمير، بتاريخ 12 نوفمبر، وفيها 4 أدوية."],
  todo: { required: true, text: "خلي الصيدلي يقرالك الأدوية ومواعيدها." },
  date: { date: "2026-11-12", time: null, text: "تاريخ الروشتة" },
  ...NO_FIELDS,
};

const GOOD_LAB: ModelExplanation = {
  status: "success",
  paper: { title: "نتيجة تحاليل معمل الأمل" },
  explain: ["دي نتيجة تحاليل من معمل الأمل، بتاريخ 8 نوفمبر."],
  todo: { required: true, text: "وري النتيجة لدكتورك عشان يشرحهالك." },
  date: { date: "2026-11-08", time: null, text: "تاريخ التحاليل" },
  ...NO_FIELDS,
};

/** The pipeline as T15 will run it: shape first, then grounding. */
const run = (answer: unknown, reading: string) =>
  groundExplanation(assertModelExplanation(answer), reading);

// ── detection is from the reading ─────────────────────────────────────────

Deno.test("a prescription and a lab result are told apart from their readings", () => {
  assertEquals(detectMedicalPaper(PRESCRIPTION_READING), "prescription");
  assertEquals(detectMedicalPaper(LAB_READING), "lab");
});

Deno.test("an ordinary paper is not medical", () => {
  assertEquals(detectMedicalPaper("فاتورة كهرباء 850 جنيه آخر موعد 15/4/2026"), null);
  assertEquals(detectMedicalPaper("نتيجة امتحان الصف الرابع"), null);
});

Deno.test("a prescription wins when it also mentions tests", () => {
  assertEquals(detectMedicalPaper("روشتة طبية\nمطلوب تحاليل دم"), "prescription");
});

// ── prescription ──────────────────────────────────────────────────────────

Deno.test("prescription: the approved interim answer survives untouched", () => {
  const { explanation, report } = run(GOOD_PRESCRIPTION, PRESCRIPTION_READING);
  assertEquals(explanation, GOOD_PRESCRIPTION);
  assertEquals(report.medicalClaimsRemoved, 0);
  assertEquals(report.referralsAdded, 0);
});

Deno.test("prescription: says that it is one, by whom and when, and sends the user to the pharmacist", () => {
  const { explanation } = run(GOOD_PRESCRIPTION, PRESCRIPTION_READING);
  assert(explanation.explain[0].includes("روشتة"));
  assert(explanation.explain[0].includes("أحمد سمير"));
  assertEquals(explanation.date?.date, "2026-11-12");
  assert(hasReferral("prescription", explanation.todo.text));
});

Deno.test("prescription: a dose, a schedule and drug advice are removed, not shown", () => {
  const { explanation, report } = run({
    ...GOOD_PRESCRIPTION,
    explain: [
      "دي روشتة من دكتور أحمد سمير.",
      "الأوجمنتين 1 جرام مرتين في اليوم بعد الأكل.",
      "البنادول 500 ملجم للصداع.",
    ],
  }, PRESCRIPTION_READING);
  assertEquals(explanation.explain, ["دي روشتة من دكتور أحمد سمير."]);
  assertEquals(report.medicalClaimsRemoved, 2);
  assert(!explanation.explain.join(" ").includes("جرام"));
  // Removing a medical claim is not an ungrounded value: status stays success.
  assertEquals(explanation.status, "success");
});

Deno.test("prescription: a todo that tells the user how to take a drug is replaced by the referral", () => {
  const { explanation, report } = run({
    ...GOOD_PRESCRIPTION,
    todo: { required: true, text: "خد الأوجمنتين 1 جرام مرتين في اليوم." },
  }, PRESCRIPTION_READING);
  assertEquals(explanation.todo.text, PRESCRIPTION_REFERRAL);
  assertEquals(report.referralsAdded, 1);
});

Deno.test("prescription: a todo with no referral gets one appended", () => {
  const { explanation } = run({
    ...GOOD_PRESCRIPTION,
    todo: { required: false, text: "احتفظ بالروشتة." },
  }, PRESCRIPTION_READING);
  assertEquals(explanation.todo.text, `احتفظ بالروشتة. ${PRESCRIPTION_REFERRAL}`);
  assertEquals(explanation.todo.required, true);
});

// ── lab result ────────────────────────────────────────────────────────────

Deno.test("lab: the approved interim answer survives untouched", () => {
  const { explanation, report } = run(GOOD_LAB, LAB_READING);
  assertEquals(explanation, GOOD_LAB);
  assertEquals(report.medicalClaimsRemoved, 0);
  assertEquals(report.referralsAdded, 0);
});

Deno.test("lab: says that it is one and from which lab, and sends the user to the doctor", () => {
  const { explanation } = run(GOOD_LAB, LAB_READING);
  assert(explanation.explain[0].includes("تحاليل"));
  assert(explanation.explain[0].includes("معمل الأمل"));
  assert(hasReferral("lab", explanation.todo.text));
});

Deno.test("lab: a verdict on a value is removed, whether on the page or not", () => {
  const { explanation, report } = run({
    ...GOOD_LAB,
    explain: [
      "دي نتيجة تحاليل من معمل الأمل.",
      "الهيموجلوبين منخفض وده معناه فقر دم.",
      "السكر عالي.",
      "النتيجة طبيعي.",
    ],
  }, LAB_READING);
  assertEquals(explanation.explain, ["دي نتيجة تحاليل من معمل الأمل."]);
  assertEquals(report.medicalClaimsRemoved, 3);
});

Deno.test("lab: a todo with no referral gets the doctor line", () => {
  const { explanation } = run({
    ...GOOD_LAB,
    todo: { required: false, text: "الورقة دي للعلم بس." },
  }, LAB_READING);
  assertEquals(explanation.todo.text, `الورقة دي للعلم بس. ${LAB_REFERRAL}`);
});

// ── the paper is not medical ──────────────────────────────────────────────

Deno.test("an ordinary paper is not touched by the medical rules", () => {
  const reading = "فاتورة كهرباء\nالمبلغ 850 جنيه\nآخر موعد 15/4/2026";
  const answer: ModelExplanation = {
    status: "success",
    paper: { title: "فاتورة الكهربا" },
    explain: ["دي فاتورة كهربا، وفيها ارتفاع في الاستهلاك عن الشهر اللي فات."],
    todo: { required: true, text: "ادفع 850 جنيه." },
    date: { date: "2026-04-15", time: null, text: "آخر ميعاد للدفع" },
    ...NO_FIELDS,
  };
  const { explanation, report } = run(answer, reading);
  assertEquals(explanation, answer);
  assertEquals(report.medicalClaimsRemoved, 0);
  assertEquals(report.referralsAdded, 0);
});

// ── the claim detector itself ─────────────────────────────────────────────

Deno.test("the detector catches doses, schedules and verdicts", () => {
  for (
    const claim of [
      "خد حبة 500 ملجم",
      "Panadol 500 mg",
      "مرتين في اليوم",
      "بعد الأكل",
      "كل 8 ساعات",
      "النتيجة طبيعي",
      "السكر عالي",
      "غير طبيعي",
    ]
  ) {
    assert(makesMedicalClaim(claim), claim);
  }
});

Deno.test("the detector leaves the approved lines and plain counts alone", () => {
  for (
    const fine of [
      PRESCRIPTION_REFERRAL,
      LAB_REFERRAL,
      "دي روشتة من دكتور أحمد سمير، بتاريخ 12 نوفمبر، وفيها 4 أدوية.",
      "دي نتيجة تحاليل من معمل الأمل.",
    ]
  ) {
    assert(!makesMedicalClaim(fine), fine);
  }
});
