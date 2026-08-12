/**
 * F13-T05 · Tests for the amount extractor.
 *
 * Mirrors `test/features/ocr/amount_extractor_test.dart` case-for-case.
 */

import { assertEquals } from "jsr:@std/assert@1";

import { extractAmounts } from "../../functions/_shared/extractors/amount-extractor.ts";

// ── explicit currency ────────────────────────────────────────────────────────

Deno.test("amount: number + EGP", () => {
  const results = extractAmounts("250.50 EGP");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, 250.5);
  assertEquals(results[0].currency, "EGP");
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("amount: EGP + number", () => {
  const results = extractAmounts("EGP 1000");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, 1000);
  assertEquals(results[0].currency, "EGP");
});

Deno.test("amount: number + LE", () => {
  const results = extractAmounts("125.00 LE");
  assertEquals(results.length, 1);
  assertEquals(results[0].currency, "EGP");
});

Deno.test("amount: number with commas", () => {
  const results = extractAmounts("1,250.50 EGP");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, 1250.5);
});

Deno.test("amount: dollar sign", () => {
  const results = extractAmounts("$100");
  assertEquals(results.length, 1);
  assertEquals(results[0].currency, "USD");
});

Deno.test("amount: euro sign", () => {
  const results = extractAmounts("€50.00");
  assertEquals(results.length, 1);
  assertEquals(results[0].currency, "EUR");
});

// ── keyword-adjacent ─────────────────────────────────────────────────────────

Deno.test("amount: إجمالي + number", () => {
  const results = extractAmounts("إجمالي 250.50");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, 250.5);
  assertEquals(results[0].is_ambiguous, true);
});

Deno.test("amount: المطلوب: number", () => {
  const results = extractAmounts("المطلوب: 1500");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, 1500);
  assertEquals(results[0].is_ambiguous, true);
});

Deno.test("amount: القيمة number", () => {
  assertEquals(extractAmounts("القيمة 300").length, 1);
});

Deno.test("amount: مبلغ number", () => {
  assertEquals(extractAmounts("مبلغ 500").length, 1);
});

Deno.test("amount: ضريبة number", () => {
  const results = extractAmounts("ضريبة 14.00");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, 14);
});

Deno.test("amount: خصم number", () => {
  assertEquals(extractAmounts("خصم 50").length, 1);
});

// ── dedup ────────────────────────────────────────────────────────────────────

Deno.test("amount: does not duplicate when explicit and keyword overlap", () => {
  const results = extractAmounts("إجمالي 250.50 EGP");
  assertEquals(results.length, 1);
  assertEquals(results[0].currency, "EGP");
  assertEquals(results[0].is_ambiguous, false);
});

// ── multiple amounts ─────────────────────────────────────────────────────────

Deno.test("amount: extracts multiple amounts in one text", () => {
  const results = extractAmounts("ضريبة 14.00 EGP\nإجمالي 250");
  assertEquals(results.length, 2);
});

// ── no false positives ───────────────────────────────────────────────────────

Deno.test("amount: does not extract bare numbers without context", () => {
  assertEquals(extractAmounts("رقم الحساب 123456"), []);
});
