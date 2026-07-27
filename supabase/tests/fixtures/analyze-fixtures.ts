/**
 * F06-T13 · Shared test fixtures.
 *
 * Deterministic by construction: fixed uuids, a fixed instant, no clocks and no
 * randomness. Every test that needs "a valid request" or "a plausible model
 * answer" starts from here so a change to the contract shows up in one place.
 *
 * The Arabic content mirrors a real electricity bill — the vertical slice this
 * milestone is built around — but is entirely invented.
 */

import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { DEFAULT_RUNTIME_CONFIG } from "../../functions/_shared/config/runtime-config.ts";
import type { ModelAnalysis } from "../../functions/_shared/schemas/groq-output.schema.ts";

export const SESSION_ID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";
export const INSTALLATION_ID = "9c858901-8a57-4791-81fe-4c455b099bc9";
export const USER_ID = "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c";
export const REQUEST_ID = "aaaaaaaa-0000-0000-0000-000000000001";

/** Well inside the Cairo day, so no test depends on a boundary by accident. */
export const NOW = new Date("2026-07-26T09:00:00Z");
export const CAIRO_DAY = "2026-07-26";

export const OCR_TEXT = [
  "شركة جنوب القاهرة لتوزيع الكهرباء",
  "فاتورة استهلاك شهر يونيو 2026",
  "رقم الحساب 12345678",
  "إجمالي المبلغ 850.50 جنيه",
  "آخر موعد للسداد 2026-08-15",
].join("\n");

export function testConfig(overrides: Partial<RuntimeConfig> = {}): RuntimeConfig {
  return { ...DEFAULT_RUNTIME_CONFIG, ...overrides };
}

/** A request body that must pass validation unchanged. */
export function validRequestBody(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    schema_version: "1.0",
    session_id: SESSION_ID,
    installation_id: INSTALLATION_ID,
    app_version: "1.0.0",
    ocr_text: OCR_TEXT,
    detected_languages: ["ar"],
    candidates: validCandidates(),
    ...overrides,
  };
}

export function validCandidates(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    dates: [
      { raw_text: "2026-08-15", normalized_date: "2026-08-15", is_ambiguous: false },
    ],
    times: [],
    amounts: [
      { raw_text: "850.50 جنيه", value: 850.5, currency: "EGP", is_ambiguous: false },
    ],
    phones: [],
    references: [
      { raw_text: "رقم الحساب 12345678", value: "12345678", is_ambiguous: true },
    ],
    ...overrides,
  };
}

/**
 * A model answer whose every value is present in {@link OCR_TEXT}, so the
 * validation pipeline verifies it rather than downgrading it. Tests that want a
 * downgrade override a field with something the page never said.
 */
export function modelAnalysis(
  overrides: Partial<ModelAnalysis> = {},
): ModelAnalysis {
  return {
    status: "success",
    document_type: { type: "invoice", title: "فاتورة كهرباء", confidence: "high" },
    summary: {
      short: "فاتورة كهرباء شهر يونيو 2026 بمبلغ 850.50 جنيه.",
      detailed: "دي فاتورة كهرباء من شركة جنوب القاهرة، لازم تتسدد قبل 15 أغسطس.",
    },
    key_information: [
      { label: "رقم الحساب", value: "12345678", confidence: "high", source: "extracted" },
    ],
    dates: [
      {
        label: "آخر موعد للسداد",
        date: "2026-08-15",
        time: null,
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      },
    ],
    amounts: [
      { label: "إجمالي المبلغ", value: 850.5, currency: "جنيه", confidence: "high" },
    ],
    actions_required: [
      { description: "سدد الفاتورة قبل 15 أغسطس 2026.", basis: "explicit", priority: "high" },
    ],
    required_documents: [],
    instructions: ["تقدر تسدد إلكترونيًا عبر فوري."],
    warnings: [],
    missing_fields: [],
    ...overrides,
  };
}
