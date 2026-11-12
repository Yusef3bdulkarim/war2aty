/**
 * F36-T12 · Tests for grounding, dedupe and the page cap.
 *
 * Every test drives `groundExplanation` with a reading and a model answer and
 * asserts what survives. The reading is the only source of truth, exactly as
 * in production.
 */

import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  EMPTY_EXPLAIN_TEXT,
  EMPTY_TODO_TEXT,
  groundExplanation,
  pageLength,
} from "../../functions/_shared/validators/explain-grounding.ts";
import {
  EXPLAIN_PAGE_MAX_CHARS,
  type ModelExplanation,
} from "../../functions/_shared/schemas/explain-output.schema.ts";

const READING = [
  "مدرسة النور",
  "دعوة اجتماع أولياء الأمور",
  "يوم 20/11/2026 الساعة 10:00 صباحاً",
  "للاستفسار اتصل على ٠٤٥٣٣١٢٢٤٤",
  "رسوم الكتب 150 جنيه",
  "شارع الجمهورية - دمنهور",
].join("\n");

const BASE: ModelExplanation = {
  status: "success",
  paper: { title: "جواب من مدرسة النور" },
  explain: ["دي ورقة من مدرسة النور لولي أمر الطالب."],
  todo: { required: true, text: "روح الاجتماع وخد معاك بطاقتك." },
  date: { date: "2026-11-20", time: "10:00", text: "اجتماع أولياء الأمور" },
  caution: null,
  contact: { name: "مدرسة النور", phone: "0453312244" },
  place: { text: "شارع الجمهورية، دمنهور" },
};

const ground = (overrides: Partial<ModelExplanation> = {}, reading = READING) =>
  groundExplanation({ ...BASE, ...overrides }, reading);

// ── a clean answer is left alone ──────────────────────────────────────────

Deno.test("a fully grounded explanation passes through as success", () => {
  const { explanation, report } = ground();
  assertEquals(explanation, BASE);
  assertEquals(report, {
    ungroundedPhones: 0,
    ungroundedAmounts: 0,
    ungroundedDates: 0,
    ungroundedTimes: 0,
    duplicateSentences: 0,
    labelsCleaned: 0,
    medicalClaimsRemoved: 0,
    referralsAdded: 0,
    paragraphsTrimmed: 0,
    fitsPage: true,
  });
});

Deno.test("unsupported is returned untouched", () => {
  const model = { ...BASE, status: "unsupported" as const };
  assertEquals(groundExplanation(model, "").explanation, model);
});

// ── phone ─────────────────────────────────────────────────────────────────

Deno.test("an invented phone number is dropped and the status becomes partial", () => {
  const { explanation, report } = ground({ contact: { name: "المدرسة", phone: "0199999999" } });
  assertEquals(explanation.contact, null);
  assertEquals(explanation.status, "partial");
  assertEquals(report.ungroundedPhones, 1);
});

Deno.test("a phone printed in Arabic-Indic digits is grounded", () => {
  // The page prints ٠٤٥٣٣١٢٢٤٤; the model wrote ASCII.
  assertEquals(ground().explanation.contact?.phone, "0453312244");
});

Deno.test("a phone the model wrote in Arabic-Indic digits is normalised to ASCII", () => {
  const { explanation } = ground({ contact: { name: "المدرسة", phone: "٠٤٥٣٣١٢٢٤٤" } });
  assertEquals(explanation.contact?.phone, "0453312244");
  assertEquals(explanation.status, "success");
});

Deno.test("an invented phone inside a sentence drops that sentence", () => {
  const { explanation, report } = ground({
    explain: ["دي ورقة من المدرسة.", "كلم المدرسة على 01012345678 لو محتاج."],
  });
  assertEquals(explanation.explain, ["دي ورقة من المدرسة."]);
  assertEquals(report.ungroundedPhones, 1);
  assertEquals(explanation.status, "partial");
});

// ── amount ────────────────────────────────────────────────────────────────

Deno.test("an invented amount in todo is dropped by sentence", () => {
  const { explanation, report } = ground({
    todo: { required: true, text: "ادفع 900 جنيه. وخد بطاقتك معاك." },
  });
  assertEquals(explanation.todo.text, "وخد بطاقتك معاك.");
  assertEquals(report.ungroundedAmounts, 1);
  assertEquals(explanation.status, "partial");
});

Deno.test("an amount that is on the page survives", () => {
  const { explanation, report } = ground({
    todo: { required: true, text: "ادفع 150 جنيه رسوم الكتب." },
  });
  assertEquals(explanation.todo.text, "ادفع 150 جنيه رسوم الكتب.");
  assertEquals(report.ungroundedAmounts, 0);
  assertEquals(explanation.status, "success");
});

Deno.test("an amount written before its currency word is checked too", () => {
  const { report } = ground({ todo: { required: true, text: "ادفع جنيه 700 للمدرسة." } });
  assertEquals(report.ungroundedAmounts, 1);
});

Deno.test("a bare count is not an amount", () => {
  // «وفيها 4 أدوية» is the approved prescription line and must survive.
  const { explanation } = ground({ explain: ["دي روشتة وفيها 4 أدوية."] }, "روشتة طبية");
  assertEquals(explanation.explain, ["دي روشتة وفيها 4 أدوية."]);
});

Deno.test("when grounding empties todo a fixed line stands in", () => {
  const { explanation } = ground({ todo: { required: true, text: "ادفع 900 جنيه." } });
  assertEquals(explanation.todo.text, EMPTY_TODO_TEXT);
  assertEquals(explanation.todo.required, true);
});

Deno.test("when grounding empties explain a fixed line stands in", () => {
  const { explanation } = ground({ explain: ["ادفع 900 جنيه."] });
  assertEquals(explanation.explain, [EMPTY_EXPLAIN_TEXT]);
});

// ── date ──────────────────────────────────────────────────────────────────

Deno.test("a date that is on the page survives, printed day-first", () => {
  const { explanation, report } = ground();
  assertEquals(explanation.date, BASE.date);
  assertEquals(report.ungroundedDates, 0);
});

Deno.test("an invented date drops the whole card", () => {
  const { explanation, report } = ground({
    date: { date: "2026-12-25", time: null, text: "اجتماع" },
  });
  assertEquals(explanation.date, null);
  assertEquals(report.ungroundedDates, 1);
  assertEquals(explanation.status, "partial");
});

Deno.test("a missing year is not assumed: the date must be present with its year", () => {
  const { explanation } = ground({ date: { date: "2027-11-20", time: null, text: "اجتماع" } });
  assertEquals(explanation.date, null);
});

Deno.test("a time the page does not print is dropped, the date stays", () => {
  const { explanation, report } = ground({
    date: { date: "2026-11-20", time: "17:45", text: "اجتماع" },
  });
  assertEquals(explanation.date?.date, "2026-11-20");
  assertEquals(explanation.date?.time, null);
  assertEquals(report.ungroundedTimes, 1);
  assertEquals(explanation.status, "partial");
});

Deno.test("a malformed date is dropped, not repaired", () => {
  const { explanation } = ground({ date: { date: "next Tuesday", time: null, text: "x" } });
  assertEquals(explanation.date, null);
});

Deno.test("an ISO date in prose that is on the page is not mistaken for a phone", () => {
  const { explanation, report } = ground({
    explain: ["الاجتماع يوم 2026-11-20 في المدرسة."],
  });
  assertEquals(explanation.explain, ["الاجتماع يوم 2026-11-20 في المدرسة."]);
  assertEquals(report.ungroundedPhones, 0);
  assertEquals(report.ungroundedDates, 0);
});

Deno.test("an invented date in prose drops that sentence", () => {
  const { explanation, report } = ground({
    explain: ["دي ورقة من المدرسة.", "آخر ميعاد 5/1/2027 للرد."],
  });
  assertEquals(explanation.explain, ["دي ورقة من المدرسة."]);
  assertEquals(report.ungroundedDates, 1);
});

// ── repetition ────────────────────────────────────────────────────────────

Deno.test("a sentence repeated across two cards is stripped once, from explain", () => {
  const repeated = "روح الاجتماع وخد معاك بطاقتك.";
  const { explanation, report } = ground({
    explain: ["دي ورقة من المدرسة. " + repeated],
    todo: { required: true, text: repeated },
  });
  assertEquals(explanation.explain, ["دي ورقة من المدرسة."]);
  assertEquals(explanation.todo.text, repeated);
  assertEquals(report.duplicateSentences, 1);
  assertEquals(explanation.status, "success");
});

Deno.test("a repeat that differs only in punctuation and spacing is still a repeat", () => {
  const { report, explanation } = ground({
    explain: ["روح   الاجتماع وخد معاك بطاقتك"],
    todo: { required: true, text: "روح الاجتماع وخد معاك بطاقتك." },
  });
  assertEquals(report.duplicateSentences, 1);
  assertEquals(explanation.explain, [EMPTY_EXPLAIN_TEXT]);
});

Deno.test("a caution that only repeats todo becomes null", () => {
  const { explanation } = ground({
    caution: { text: "روح الاجتماع وخد معاك بطاقتك." },
    todo: { required: true, text: "روح الاجتماع وخد معاك بطاقتك." },
  });
  assertEquals(explanation.caution, null);
});

Deno.test("a sentence repeated inside explain is kept once", () => {
  const { explanation, report } = ground({
    explain: ["دي ورقة من المدرسة.", "دي ورقة من المدرسة."],
  });
  assertEquals(explanation.explain, ["دي ورقة من المدرسة."]);
  assertEquals(report.duplicateSentences, 1);
});

// ── labels ────────────────────────────────────────────────────────────────

Deno.test("a heading the app owns is stripped and counted", () => {
  const { explanation, report } = ground({
    explain: ["الشرح: دي ورقة من المدرسة."],
    todo: { required: true, text: "**المطلوب:** روح الاجتماع." },
  });
  assertEquals(explanation.explain, ["دي ورقة من المدرسة."]);
  assertEquals(explanation.todo.text, "روح الاجتماع.");
  assertEquals(report.labelsCleaned, 2);
});

Deno.test("a colon in the middle of a sentence is prose, not a label", () => {
  const text = "خد معاك: بطاقتك وكراسة الواجب.";
  assertEquals(ground({ todo: { required: true, text } }).explanation.todo.text, text);
});

// ── the page cap ──────────────────────────────────────────────────────────

Deno.test("a 1,200-character response is driven to 850 with todo and date intact", () => {
  const paragraph = (n: number) => `${"ا".repeat(270)} ${n}.`;
  const model: ModelExplanation = {
    ...BASE,
    explain: [1, 2, 3, 4].map(paragraph),
    caution: { text: "بلّغ المدرسة قبل الميعاد." },
  };
  assert(pageLength(model) > 1_000);

  const { explanation, report } = groundExplanation(model, READING);
  assert(pageLength(explanation) <= EXPLAIN_PAGE_MAX_CHARS);
  assertEquals(report.fitsPage, true);
  assert(report.paragraphsTrimmed > 0);
  // The LAST paragraphs went; the first stays.
  assertEquals(explanation.explain[0], paragraph(1));
  assert(!explanation.explain.includes(paragraph(4)));
  // What the user acts on is untouched.
  assertEquals(explanation.todo, model.todo);
  assertEquals(explanation.date, model.date);
  assertEquals(explanation.caution, model.caution);
  assertEquals(explanation.contact, model.contact);
});

Deno.test("trimming for length does not make the status partial", () => {
  const model: ModelExplanation = {
    ...BASE,
    explain: [1, 2, 3, 4].map((n) => `${"ا".repeat(210)} ${n}.`),
  };
  assertEquals(groundExplanation(model, READING).explanation.status, "success");
});

Deno.test("when nothing is left to trim the page is reported as not fitting", () => {
  const model: ModelExplanation = {
    ...BASE,
    todo: { required: true, text: "ب".repeat(900) },
  };
  const { explanation, report } = groundExplanation(model, READING);
  assertEquals(report.fitsPage, false);
  assertEquals(explanation.explain.length, 1);
  assertEquals(explanation.todo.text, model.todo.text);
});

Deno.test("a page already under the cap loses no paragraph", () => {
  const model: ModelExplanation = { ...BASE, explain: ["أ.", "ب.", "ج."] };
  assertEquals(groundExplanation(model, READING).explanation.explain, ["أ.", "ب.", "ج."]);
});

// ── privacy ───────────────────────────────────────────────────────────────

Deno.test("the report holds counts and a boolean, never a value from the page", () => {
  const { report } = ground({
    contact: { name: "x", phone: "0199999999" },
    todo: { required: true, text: "ادفع 900 جنيه." },
  });
  for (const value of Object.values(report)) {
    assert(typeof value === "number" || typeof value === "boolean");
  }
  const text = JSON.stringify(report);
  assert(!text.includes("0199999999"));
  assert(!text.includes("900"));
  assertStringIncludes(text, "ungroundedPhones");
});
