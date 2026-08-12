/**
 * F13-T05 · Tests for the date extractor.
 *
 * Mirrors `test/features/ocr/date_extractor_test.dart` case-for-case so the
 * two pipelines (offline Dart, online Azure-text) stay provably in sync.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { extractDates } from "../../functions/_shared/extractors/date-extractor.ts";

// ── numeric dates ───────────────────────────────────────────────────────────

Deno.test("date: DD/MM/YYYY", () => {
  const results = extractDates("التاريخ 25/08/2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-08-25");
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("date: DD-MM-YYYY", () => {
  const results = extractDates("15-03-2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-03-15");
});

Deno.test("date: DD.MM.YYYY", () => {
  const results = extractDates("01.12.2025");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2025-12-01");
});

Deno.test("date: 2-digit year expands to 20xx", () => {
  const results = extractDates("25/08/26");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-08-25");
});

Deno.test("date: ambiguous when day and month both <= 12", () => {
  const results = extractDates("01/02/2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].is_ambiguous, true);
  // Parsed as DD/MM (day-first, Egyptian convention)
  assertEquals(results[0].normalized_date, "2026-02-01");
});

Deno.test("date: not ambiguous when day > 12", () => {
  const results = extractDates("25/01/2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("date: not ambiguous when day equals month", () => {
  const results = extractDates("05/05/2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("date: rejects invalid month > 12", () => {
  assertEquals(extractDates("25/13/2026"), []);
});

Deno.test("date: rejects invalid day > 31", () => {
  assertEquals(extractDates("32/01/2026"), []);
});

Deno.test("date: handles spaces around separators", () => {
  const results = extractDates("25 / 08 / 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-08-25");
});

Deno.test("date: multiple dates in one text", () => {
  const results = extractDates("من 01/01/2026 إلى 31/12/2026");
  assertEquals(results.length, 2);
});

// ── Arabic month names ──────────────────────────────────────────────────────

Deno.test("date: day + Arabic month + year", () => {
  const results = extractDates("25 يناير 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-01-25");
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("date: with من prefix", () => {
  const results = extractDates("15 من فبراير 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-02-15");
});

Deno.test("date: Arabic month without year is ambiguous", () => {
  const results = extractDates("25 مارس");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, null);
  assertEquals(results[0].is_ambiguous, true);
});

Deno.test("date: handles أبريل / إبريل / ابريل variants", () => {
  for (const variant of ["أبريل", "إبريل", "ابريل"]) {
    const results = extractDates(`10 ${variant} 2026`);
    assert(results.length === 1, `${variant} should match`);
    assertEquals(results[0].normalized_date, "2026-04-10");
  }
});

Deno.test("date: handles يونيو / يونيه variants", () => {
  const r1 = extractDates("1 يونيو 2026");
  const r2 = extractDates("1 يونيه 2026");
  assertEquals(r1[0].normalized_date, "2026-06-01");
  assertEquals(r2[0].normalized_date, "2026-06-01");
});

// ── English month names ─────────────────────────────────────────────────────

Deno.test("date: day + English month + year", () => {
  const results = extractDates("25 January 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-01-25");
});

Deno.test("date: abbreviated month", () => {
  const results = extractDates("15 Feb 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-02-15");
});

Deno.test("date: case insensitive", () => {
  const results = extractDates("1 MARCH 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-03-01");
});

Deno.test("date: with of prefix", () => {
  const results = extractDates("5 of May 2026");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, "2026-05-05");
});

// ── Hijri dates ──────────────────────────────────────────────────────────────

Deno.test("date: detects Hijri month name with year", () => {
  const results = extractDates("5 محرم 1448");
  assertEquals(results.length, 1);
  assertEquals(results[0].normalized_date, null);
  assertEquals(results[0].is_ambiguous, true);
  assert(results[0].raw_text.includes("محرم"));
});

Deno.test("date: detects رمضان", () => {
  const results = extractDates("1 رمضان 1448");
  assertEquals(results.length, 1);
  assertEquals(results[0].is_ambiguous, true);
});

Deno.test("date: detects ذو الحجة", () => {
  const results = extractDates("10 ذو الحجة 1448");
  assertEquals(results.length, 1);
  assertEquals(results[0].is_ambiguous, true);
});

// ── no false positives ───────────────────────────────────────────────────────

Deno.test("date: does not extract bare numbers", () => {
  assertEquals(extractDates("رقم الحساب 123456"), []);
});

Deno.test("date: does not extract phone numbers", () => {
  assertEquals(extractDates("01012345678"), []);
});
