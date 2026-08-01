/**
 * F13-T05 · Tests for the time extractor.
 *
 * Mirrors `test/features/ocr/time_extractor_test.dart` case-for-case.
 */

import { assertEquals } from "jsr:@std/assert@1";

import { extractTimes } from "../../functions/_shared/extractors/time-extractor.ts";

// ── 24h format ───────────────────────────────────────────────────────────────

Deno.test("time: HH:MM", () => {
  const results = extractTimes("الساعة 14:30");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 14);
  assertEquals(results[0].minute, 30);
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("time: HH.MM", () => {
  const results = extractTimes("الموعد 09.00");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 9);
  assertEquals(results[0].minute, 0);
});

Deno.test("time: 13:00-23:59 are unambiguous", () => {
  assertEquals(extractTimes("13:00")[0].is_ambiguous, false);
});

Deno.test("time: 00:00 is unambiguous", () => {
  assertEquals(extractTimes("00:00")[0].is_ambiguous, false);
});

Deno.test("time: 1:00-12:59 without marker are ambiguous", () => {
  assertEquals(extractTimes("9:30")[0].is_ambiguous, true);
});

// ── Arabic AM/PM ─────────────────────────────────────────────────────────────

Deno.test("time: صباحاً (AM)", () => {
  const results = extractTimes("9:30 صباحاً");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 9);
  assertEquals(results[0].minute, 30);
  assertEquals(results[0].is_ambiguous, false);
});

Deno.test("time: مساءً (PM)", () => {
  const results = extractTimes("3:00 مساءً");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 15);
  assertEquals(results[0].minute, 0);
});

Deno.test("time: ص abbreviation (AM)", () => {
  const results = extractTimes("10:00 ص");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 10);
});

Deno.test("time: م abbreviation (PM)", () => {
  const results = extractTimes("7:45 م");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 19);
  assertEquals(results[0].minute, 45);
});

Deno.test("time: 12 PM stays 12", () => {
  assertEquals(extractTimes("12:00 مساءً")[0].hour, 12);
});

Deno.test("time: 12 AM becomes 0", () => {
  assertEquals(extractTimes("12:00 صباحاً")[0].hour, 0);
});

// ── English AM/PM ────────────────────────────────────────────────────────────

Deno.test("time: AM", () => {
  const results = extractTimes("9:30 AM");
  assertEquals(results.length, 1);
  assertEquals(results[0].hour, 9);
});

Deno.test("time: PM", () => {
  assertEquals(extractTimes("3:00 PM")[0].hour, 15);
});

Deno.test("time: a.m.", () => {
  assertEquals(extractTimes("10:00 a.m.")[0].hour, 10);
});

Deno.test("time: p.m.", () => {
  assertEquals(extractTimes("5:30 p.m.")[0].hour, 17);
});

// ── edge cases ───────────────────────────────────────────────────────────────

Deno.test("time: rejects invalid minute > 59", () => {
  assertEquals(extractTimes("10:60"), []);
});

Deno.test("time: rejects hour > 23 without AM/PM", () => {
  assertEquals(extractTimes("25:00"), []);
});

Deno.test("time: multiple times in one text", () => {
  const results = extractTimes("من 9:00 صباحاً إلى 5:00 مساءً");
  assertEquals(results.length, 2);
  assertEquals(results[0].hour, 9);
  assertEquals(results[1].hour, 17);
});
