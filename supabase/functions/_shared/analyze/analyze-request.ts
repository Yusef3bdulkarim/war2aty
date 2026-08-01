/**
 * F06-T13 / F13-T09 · Parsing and validating the analyze-document request (§29).
 *
 * Nothing downstream sees the raw body. By the time this returns, every field
 * has been proven to be the type and shape the prompt builder, the quota tables
 * and the validation pipeline assume — so none of them has to re-check.
 *
 * ── Two request shapes, one envelope (§29 v2) ────────────────────────────
 * A discriminated `input_type` now picks the shape: `"text"` is today's
 * Tesseract → on-device extractors → OCR text + candidate hints, parsed here
 * by `parseAnalyzeRequest`. `"image"` is the online Azure/Google pipeline
 * (locked decision #1), parsed by `parseAnalyzeImageRequest` below. Each shape
 * has its OWN closed allow-list — not one shared list with everything
 * optional — so a text body can never smuggle image bytes and an image body
 * can never smuggle `ocr_text`/`candidates`.
 *
 * `parseAnalyzeImageRequest` is called from `analyze-handler.ts` (F13-T11),
 * gated behind `RuntimeConfig.azureOcrEnabled`.
 *
 * ── Why unknown properties are rejected ──────────────────────────────────
 * Each shape's schema sets `additionalProperties: false`. For the TEXT shape
 * this is still a privacy tripwire, just a narrower one than it used to be:
 * §7's privacy model changed the day the image path was designed — a
 * photograph now legitimately reaches this Edge Function, but only over the
 * image shape, gated behind `azureOcrEnabled`. A text-shaped request must
 * still never carry an `image` key, exactly as strictly as before.
 *
 * ── Why malformed candidates are dropped, not rejected ───────────────────
 * Candidates are HINTS produced by on-device regexes (§29). A single odd entry
 * must not cost the user their whole analysis, and it is harmless to discard:
 * the model reads `ocr_text` itself and the pipeline verifies against it. The
 * structure around them — the object and its five arrays — is still required,
 * because a missing array is a client bug, not a bad match.
 *
 * PRIVACY: no OCR text and no image byte parsed here is ever logged or
 * attached to an error. Every rejection is a fixed `ApiError` factory message.
 */

import type { RuntimeConfig } from "../config/runtime-config.ts";
import { isAppVersionSupported } from "../config/runtime-config.ts";
import { ApiError } from "../errors/api-error.ts";
import { isUuid } from "../http/request-id.ts";
import type {
  AmountCandidate,
  DateCandidate,
  ExtractedCandidates,
  PhoneCandidate,
  ReferenceCandidate,
  TimeCandidate,
} from "../prompts/analysis-prompt.ts";

export interface AnalyzeRequest {
  readonly inputType: "text";
  readonly sessionId: string;
  readonly installationId: string;
  readonly appVersion: string;
  readonly ocrText: string;
  readonly detectedLanguages: readonly string[];
  readonly candidates: ExtractedCandidates;
  /**
   * How many candidate entries were discarded as malformed or over the cap.
   * A count, never the entries — diagnostics only.
   */
  readonly droppedCandidates: number;
}

/** The decoded image-intake shape (§29 v2), routed by `analyze-handler.ts` (F13-T11). */
export interface AnalyzeImageRequest {
  readonly inputType: "image";
  readonly sessionId: string;
  readonly installationId: string;
  readonly appVersion: string;
  readonly image: {
    /** Decoded bytes — the caller never sees the base64 string again. */
    readonly data: Uint8Array;
    readonly mimeType: string;
  };
}

const TEXT_TOP_LEVEL_KEYS: ReadonlySet<string> = new Set([
  "schema_version",
  "session_id",
  "installation_id",
  "app_version",
  "input_type",
  "ocr_text",
  "detected_languages",
  "candidates",
]);

const IMAGE_TOP_LEVEL_KEYS: ReadonlySet<string> = new Set([
  "schema_version",
  "session_id",
  "installation_id",
  "app_version",
  "input_type",
  "image",
]);

/** Photo formats the capture flow (F04) and `doclens` crop (F13-T12) may produce. */
const IMAGE_MIME_TYPES: ReadonlySet<string> = new Set(["image/jpeg", "image/png"]);

const BASE64_PATTERN = /^[A-Za-z0-9+/]+={0,2}$/;

const CANDIDATE_KINDS = [
  "dates",
  "times",
  "amounts",
  "phones",
  "references",
] as const;

const APP_VERSION_PATTERN = /^\d+\.\d+\.\d+$/;
const LANGUAGE_TAG_PATTERN = /^[a-z]{2,3}$/;

/**
 * Per-kind ceiling on candidates.
 *
 * `ocr_text` is capped by `maxOcrCharacters`, but the candidate arrays were
 * not capped by anything: a client bug (or a hostile caller with a valid
 * anonymous token) could send tens of thousands of entries and blow up the
 * prompt — which is billed per token and reserved against a per-minute quota.
 * A real document produces a handful.
 */
const MAX_CANDIDATES_PER_KIND = 100;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function optionalString(value: unknown): string | null {
  // Absent and explicit null mean the same thing: the extractor could not
  // resolve it. Neither is an error (§29 allows both).
  if (value === undefined || value === null) return null;
  return typeof value === "string" ? value : null;
}

function finiteNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function integerInRange(value: unknown, min: number, max: number): number | null {
  if (typeof value !== "number" || !Number.isInteger(value)) return null;
  return value >= min && value <= max ? value : null;
}

function boolean(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

// ── candidate parsers ─────────────────────────────────────────────────────
// Each returns null for an entry that cannot be trusted; the caller drops it.
// Only known fields are copied, so an unknown property inside a candidate can
// never reach the prompt even though it does not fail the request.

function parseDateCandidate(raw: unknown): DateCandidate | null {
  if (!isRecord(raw)) return null;

  const rawText = nonEmptyString(raw.raw_text);
  const isAmbiguous = boolean(raw.is_ambiguous);
  if (rawText === null || isAmbiguous === null) return null;

  return {
    raw_text: rawText,
    normalized_date: optionalString(raw.normalized_date),
    is_ambiguous: isAmbiguous,
  };
}

function parseTimeCandidate(raw: unknown): TimeCandidate | null {
  if (!isRecord(raw)) return null;

  const rawText = nonEmptyString(raw.raw_text);
  const hour = integerInRange(raw.hour, 0, 23);
  const minute = integerInRange(raw.minute, 0, 59);
  const isAmbiguous = boolean(raw.is_ambiguous);
  if (rawText === null || hour === null || minute === null || isAmbiguous === null) {
    return null;
  }

  return { raw_text: rawText, hour, minute, is_ambiguous: isAmbiguous };
}

function parseAmountCandidate(raw: unknown): AmountCandidate | null {
  if (!isRecord(raw)) return null;

  const rawText = nonEmptyString(raw.raw_text);
  const isAmbiguous = boolean(raw.is_ambiguous);
  if (rawText === null || isAmbiguous === null) return null;

  return {
    raw_text: rawText,
    value: finiteNumber(raw.value),
    currency: optionalString(raw.currency),
    is_ambiguous: isAmbiguous,
  };
}

function parsePhoneCandidate(raw: unknown): PhoneCandidate | null {
  if (!isRecord(raw)) return null;

  const rawText = nonEmptyString(raw.raw_text);
  const normalized = nonEmptyString(raw.normalized_number);
  const isAmbiguous = boolean(raw.is_ambiguous);
  if (rawText === null || normalized === null || isAmbiguous === null) return null;

  return {
    raw_text: rawText,
    normalized_number: normalized,
    is_ambiguous: isAmbiguous,
  };
}

function parseReferenceCandidate(raw: unknown): ReferenceCandidate | null {
  if (!isRecord(raw)) return null;

  const rawText = nonEmptyString(raw.raw_text);
  const value = nonEmptyString(raw.value);
  const isAmbiguous = boolean(raw.is_ambiguous);
  if (rawText === null || value === null || isAmbiguous === null) return null;

  return { raw_text: rawText, value, is_ambiguous: isAmbiguous };
}

const CANDIDATE_PARSERS = {
  dates: parseDateCandidate,
  times: parseTimeCandidate,
  amounts: parseAmountCandidate,
  phones: parsePhoneCandidate,
  references: parseReferenceCandidate,
} as const;

interface ParsedCandidates {
  readonly candidates: ExtractedCandidates;
  readonly dropped: number;
}

function parseCandidates(raw: unknown): ParsedCandidates {
  if (!isRecord(raw)) throw ApiError.invalidRequest();

  for (const key of Object.keys(raw)) {
    if (!(CANDIDATE_KINDS as readonly string[]).includes(key)) {
      throw ApiError.invalidRequest();
    }
  }

  const parsed: Record<string, unknown[]> = {};
  let dropped = 0;

  for (const kind of CANDIDATE_KINDS) {
    const entries = raw[kind];
    // Required by §29 — a missing array is a malformed client, not an empty
    // result, and the two must not look the same.
    if (!Array.isArray(entries)) throw ApiError.invalidRequest();

    if (entries.length > MAX_CANDIDATES_PER_KIND) {
      dropped += entries.length - MAX_CANDIDATES_PER_KIND;
    }

    const kept: unknown[] = [];
    for (const entry of entries.slice(0, MAX_CANDIDATES_PER_KIND)) {
      const value = CANDIDATE_PARSERS[kind](entry);
      if (value === null) dropped += 1;
      else kept.push(value);
    }
    parsed[kind] = kept;
  }

  return {
    candidates: parsed as unknown as ExtractedCandidates,
    dropped,
  };
}

/**
 * Reads the OCR engine's language tags.
 *
 * Unrecognised tags are dropped rather than refused. They only widen a hint in
 * the prompt, so an engine that one day reports `ar-EG` instead of `ar` must
 * not start failing analyses over a label.
 */
function parseLanguages(raw: unknown): string[] {
  if (!Array.isArray(raw)) throw ApiError.invalidRequest();

  const tags: string[] = [];
  for (const entry of raw) {
    if (typeof entry !== "string") continue;
    const tag = entry.trim().toLowerCase();
    if (LANGUAGE_TAG_PATTERN.test(tag) && !tags.includes(tag)) tags.push(tag);
  }
  return tags;
}

/**
 * Validates a decoded request body against the contract and the live config.
 *
 * @param body Whatever `JSON.parse` produced — not assumed to be an object.
 * @throws ApiError INVALID_REQUEST / UNSUPPORTED_SCHEMA / UNSUPPORTED_APP_VERSION
 */
export function parseAnalyzeRequest(
  body: unknown,
  config: RuntimeConfig,
): AnalyzeRequest {
  if (!isRecord(body)) throw ApiError.invalidRequest();

  for (const key of Object.keys(body)) {
    if (!TEXT_TOP_LEVEL_KEYS.has(key)) throw ApiError.invalidRequest();
  }

  // Version first: if the client is speaking a different contract, nothing
  // below can be assumed to mean what this code thinks it means (§29 rule 1).
  const schemaVersion = body.schema_version;
  if (typeof schemaVersion !== "string") throw ApiError.invalidRequest();
  if (schemaVersion !== config.schemaVersion) throw ApiError.unsupportedSchema();

  // §29 v2: the discriminant must actually say "text" — a body that is
  // shaped like this one but carries `input_type: "image"` (or omits it) is
  // not this contract, not a v1 client either (v1 had no such field at all
  // and would already have failed the schema_version check above).
  if (body.input_type !== "text") throw ApiError.invalidRequest();

  // A version that does not match the pattern is a malformed field, not an old
  // app — §29's own schema draws the line there, and telling someone to update
  // an app that is already current would send them nowhere.
  const appVersion = body.app_version;
  if (typeof appVersion !== "string" || !APP_VERSION_PATTERN.test(appVersion)) {
    throw ApiError.invalidRequest();
  }
  if (!isAppVersionSupported(appVersion, config.minimumAppVersion)) {
    throw ApiError.unsupportedAppVersion();
  }

  const sessionId = body.session_id;
  if (typeof sessionId !== "string" || !isUuid(sessionId)) {
    throw ApiError.invalidRequest();
  }

  const installationId = body.installation_id;
  if (typeof installationId !== "string" || !isUuid(installationId)) {
    throw ApiError.invalidRequest();
  }

  const ocrText = body.ocr_text;
  if (typeof ocrText !== "string") throw ApiError.invalidRequest();
  // Whitespace-only is empty for our purposes: there is nothing to analyse,
  // and paying an AI provider to say so would be absurd (§29 rule 3).
  if (ocrText.trim().length === 0) throw ApiError.invalidRequest();
  if (ocrText.length > config.maxOcrCharacters) throw ApiError.invalidRequest();

  const detectedLanguages = parseLanguages(body.detected_languages);
  const { candidates, dropped } = parseCandidates(body.candidates);

  return {
    inputType: "text",
    sessionId: sessionId.toLowerCase(),
    installationId: installationId.toLowerCase(),
    appVersion,
    ocrText,
    detectedLanguages,
    candidates,
    droppedCandidates: dropped,
  };
}

// ── image-intake path (§29 v2, F13-T09/T11) ────────────────────────────────

/**
 * Decodes and bounds-checks a base64 image payload.
 *
 * Rejects on shape before spending a decode on it: an empty string, one whose
 * length is not a multiple of 4, or one containing anything outside the
 * base64 alphabet can never be valid, and the length check catches a grossly
 * oversized body before `atob` allocates for it.
 */
function decodeImageBase64(data: string, maxBytes: number): Uint8Array {
  if (data.length === 0 || data.length % 4 !== 0 || !BASE64_PATTERN.test(data)) {
    throw ApiError.invalidRequest();
  }

  // Base64 expands bytes by 4/3; reject before decoding rather than after.
  const approximateBytes = (data.length / 4) * 3;
  if (approximateBytes > maxBytes + 4) throw ApiError.invalidRequest();

  let binary: string;
  try {
    binary = atob(data);
  } catch {
    throw ApiError.invalidRequest();
  }

  if (binary.length === 0 || binary.length > maxBytes) throw ApiError.invalidRequest();

  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Validates a decoded image-intake body against the contract and the live
 * config. Mirrors {@link parseAnalyzeRequest}'s envelope checks exactly —
 * only `ocr_text`/`detected_languages`/`candidates` are replaced by `image`.
 *
 * @param body Whatever `JSON.parse` produced — not assumed to be an object.
 * @throws ApiError INVALID_REQUEST / UNSUPPORTED_SCHEMA / UNSUPPORTED_APP_VERSION
 */
export function parseAnalyzeImageRequest(
  body: unknown,
  config: RuntimeConfig,
): AnalyzeImageRequest {
  if (!isRecord(body)) throw ApiError.invalidRequest();

  for (const key of Object.keys(body)) {
    if (!IMAGE_TOP_LEVEL_KEYS.has(key)) throw ApiError.invalidRequest();
  }

  const schemaVersion = body.schema_version;
  if (typeof schemaVersion !== "string") throw ApiError.invalidRequest();
  if (schemaVersion !== config.schemaVersion) throw ApiError.unsupportedSchema();

  if (body.input_type !== "image") throw ApiError.invalidRequest();

  const appVersion = body.app_version;
  if (typeof appVersion !== "string" || !APP_VERSION_PATTERN.test(appVersion)) {
    throw ApiError.invalidRequest();
  }
  if (!isAppVersionSupported(appVersion, config.minimumAppVersion)) {
    throw ApiError.unsupportedAppVersion();
  }

  const sessionId = body.session_id;
  if (typeof sessionId !== "string" || !isUuid(sessionId)) {
    throw ApiError.invalidRequest();
  }

  const installationId = body.installation_id;
  if (typeof installationId !== "string" || !isUuid(installationId)) {
    throw ApiError.invalidRequest();
  }

  const image = body.image;
  if (!isRecord(image)) throw ApiError.invalidRequest();
  for (const key of Object.keys(image)) {
    if (key !== "data" && key !== "mime_type") throw ApiError.invalidRequest();
  }

  const mimeType = image.mime_type;
  if (typeof mimeType !== "string" || !IMAGE_MIME_TYPES.has(mimeType)) {
    throw ApiError.invalidRequest();
  }

  const data = image.data;
  if (typeof data !== "string") throw ApiError.invalidRequest();

  const bytes = decodeImageBase64(data, config.maxImageBytes);

  return {
    inputType: "image",
    sessionId: sessionId.toLowerCase(),
    installationId: installationId.toLowerCase(),
    appVersion,
    image: { data: bytes, mimeType },
  };
}
