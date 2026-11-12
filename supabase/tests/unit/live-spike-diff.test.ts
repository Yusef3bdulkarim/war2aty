/**
 * F36-T02 · Tests for the Live spike's verbatim judgement.
 *
 * The spike's whole verdict — and with it whether F37 proceeds — is a word
 * error rate over Arabic text that a transcriber wrote. If the folding is wrong
 * the gate reads "paraphrasing" on a clean read, or the reverse. These are the
 * only pieces of `live-spike.ts` that decide anything, so they are the pieces
 * under test; the WebSocket session itself is the owner's run.
 */

import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";

import { diffWords, normalise, words } from "../../tools/live-spike.ts";

const SENTENCE = "الاجتماع يوم 20 نوفمبر الساعة 10 الصبح.";

// ── folding ──────────────────────────────────────────────────────────────────

Deno.test("normalise: drops diacritics and tatweel", () => {
  assertEquals(normalise("لازم تبلّغ المدرســة"), normalise("لازم تبلغ المدرسه"));
});

Deno.test("normalise: folds the alef family, ya and ta marbuta", () => {
  assertEquals(normalise("أولياء الأمور"), normalise("اولياء الامور"));
  assertEquals(normalise("على مدرسة"), normalise("علي مدرسه"));
});

Deno.test("normalise: folds Arabic-Indic digits to ASCII", () => {
  assertEquals(normalise("٢٠ نوفمبر"), "20 نوفمبر");
  assertEquals(normalise("۱۰ الصبح"), "10 الصبح");
});

Deno.test("normalise: strips punctuation and collapses whitespace", () => {
  assertEquals(normalise("  روح الاجتماع،   بنفسك!  "), "روح الاجتماع بنفسك");
});

Deno.test("words: empty text yields no words, not one empty word", () => {
  assertEquals(words("   "), []);
  assertEquals(words("؟!"), []);
});

// ── the verdict ──────────────────────────────────────────────────────────────

Deno.test("diff: an identical read is 0% WER", () => {
  const diff = diffWords(words(SENTENCE), words(SENTENCE));
  assertEquals(diff.wer, 0);
  assertEquals(diff.dropped, []);
  assertEquals(diff.added, []);
});

Deno.test("diff: a read that differs only by spelling is 0% WER", () => {
  const heard = "الإجتماع يوم ٢٠ نوفمبر الساعه ١٠ الصبح";
  assertEquals(diffWords(words(SENTENCE), words(heard)).wer, 0);
});

Deno.test("diff: an added greeting is listed, and stays under the 5% gate on a page", () => {
  const source = words([SENTENCE, SENTENCE, SENTENCE].join(" "));
  const heard = words(["أهلاً بيك", SENTENCE, SENTENCE, SENTENCE].join(" "));
  const diff = diffWords(source, heard);
  assertEquals(diff.added, ["اهلا", "بيك"]);
  assertEquals(diff.dropped, []);
  assertAlmostEquals(diff.wer, 2 / source.length, 1e-9);
});

Deno.test("diff: a dropped number is listed as dropped", () => {
  const heard = "الاجتماع يوم نوفمبر الساعة 10 الصبح";
  const diff = diffWords(words(SENTENCE), words(heard));
  assertEquals(diff.dropped, ["20"]);
  assertEquals(diff.added, []);
});

Deno.test("diff: a paraphrase lands far above the 15% gate", () => {
  const heard = "المدرسة عاملة اجتماع لأولياء الأمور الشهر الجاي الصبح";
  const diff = diffWords(words(SENTENCE), words(heard));
  assertEquals(diff.wer > 0.15, true);
});

Deno.test("diff: nothing heard at all is 100% WER, never a division by zero", () => {
  assertEquals(diffWords(words(SENTENCE), []).wer, 1);
  assertEquals(diffWords([], []).wer, 1);
});
