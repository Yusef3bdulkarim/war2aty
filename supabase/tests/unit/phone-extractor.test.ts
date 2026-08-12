/**
 * F13-T05 · Tests for the phone extractor.
 *
 * Mirrors `test/features/ocr/phone_extractor_test.dart` case-for-case.
 */

import { assertEquals } from "jsr:@std/assert@1";

import { extractPhones } from "../../functions/_shared/extractors/phone-extractor.ts";

// ── local mobile numbers ─────────────────────────────────────────────────────

Deno.test("phone: contiguous 11-digit mobile", () => {
  const results = extractPhones("اتصل 01012345678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("phone: 010 prefix", () => {
  assertEquals(extractPhones("01098765432").length, 1);
});

Deno.test("phone: 011 prefix", () => {
  assertEquals(extractPhones("01112345678").length, 1);
});

Deno.test("phone: 012 prefix", () => {
  assertEquals(extractPhones("01212345678").length, 1);
});

Deno.test("phone: 015 prefix", () => {
  assertEquals(extractPhones("01512345678").length, 1);
});

// ── whitespace reassembly ────────────────────────────────────────────────────

Deno.test("phone: spaces between groups", () => {
  const results = extractPhones("010 1234 5678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
  assertEquals(results[0].is_ambiguous, true);
});

Deno.test("phone: dashes between groups", () => {
  const results = extractPhones("010-1234-5678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
});

Deno.test("phone: dots between groups", () => {
  const results = extractPhones("010.1234.5678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
});

Deno.test("phone: mixed separators", () => {
  const results = extractPhones("010 1234-5678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
});

// ── international format ─────────────────────────────────────────────────────

Deno.test("phone: +20 prefix", () => {
  const results = extractPhones("+201012345678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
});

Deno.test("phone: 002 prefix", () => {
  const results = extractPhones("00201012345678");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_number, "01012345678");
});

// ── invalid numbers ──────────────────────────────────────────────────────────

Deno.test("phone: rejects non-Egyptian prefix", () => {
  assertEquals(extractPhones("01312345678"), []);
});

Deno.test("phone: rejects too few digits", () => {
  assertEquals(extractPhones("0101234567"), []);
});

Deno.test("phone: deduplicates same number appearing twice", () => {
  assertEquals(extractPhones("01012345678 or 01012345678").length, 1);
});

// ── multiple numbers ─────────────────────────────────────────────────────────

Deno.test("phone: extracts two different numbers", () => {
  const results = extractPhones("خدمة العملاء 01012345678 أو 01198765432");
  assertEquals(results.length, 2);
});
