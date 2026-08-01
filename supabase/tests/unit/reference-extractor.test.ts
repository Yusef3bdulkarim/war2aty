/**
 * F13-T05 · Tests for the reference extractor.
 *
 * Mirrors `test/features/ocr/reference_extractor_test.dart` case-for-case.
 */

import { assertEquals } from "jsr:@std/assert@1";

import { extractReferences } from "../../functions/_shared/extractors/reference-extractor.ts";

Deno.test("reference: رقم الحساب + digits", () => {
  const results = extractReferences("رقم الحساب 1234567890");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, "1234567890");
  assertEquals(results[0].is_ambiguous, true);
});

Deno.test("reference: رقم الفاتورة: digits", () => {
  const results = extractReferences("رقم الفاتورة: 98765");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, "98765");
});

Deno.test("reference: رقم مرجعي # alphanumeric", () => {
  const results = extractReferences("رقم مرجعي# ABC-1234");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, "ABC-1234");
});

Deno.test("reference: رقم الحجز with mixed case", () => {
  const results = extractReferences("رقم الحجز BK2026XY");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, "BK2026XY");
});

Deno.test("reference: كود keyword", () => {
  const results = extractReferences("كود 5678");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, "5678");
});

Deno.test("reference: English Ref keyword", () => {
  const results = extractReferences("Ref: INV-2026-001");
  assertEquals(results.length, 1);
  assertEquals(results[0].value, "INV-2026-001");
});

Deno.test("reference: Invoice keyword", () => {
  assertEquals(extractReferences("Invoice 12345").length, 1);
});

Deno.test("reference: rejects values shorter than 4 characters", () => {
  assertEquals(extractReferences("رقم الحساب 123"), []);
});

Deno.test("reference: deduplicates same reference value", () => {
  const results = extractReferences("رقم الفاتورة 12345\nرقم الحساب 12345");
  assertEquals(results.length, 1);
});

Deno.test("reference: extracts multiple different references", () => {
  const results = extractReferences("رقم الفاتورة 98765\nرقم الحساب 1234567890");
  assertEquals(results.length, 2);
});

Deno.test("reference: does not extract bare numbers without keywords", () => {
  assertEquals(extractReferences("المبلغ 250.50"), []);
});
