/**
 * F36-T14 · Parsing and validating the explain-document request (§33).
 *
 * Nothing downstream sees the raw body. By the time this returns, every field
 * has been proven to be the type and shape the handler assumes.
 *
 * ── Modelled on `parseAnalyzeImageRequest`, deliberately not shared with it ──
 * The image-intake shape is nearly the same, and sharing the parser would be
 * the shorter diff. It would also couple a new, independently versioned
 * contract to the frozen one: `analyze-document` and `ocr-document` serve
 * published 1.0.x builds until those are out of support, and a change to either
 * parser for the sake of this endpoint would be a change to them. So the
 * envelope checks are repeated here, and the base64 decoder is a private copy.
 * When the freeze lifts, the two decoders are the obvious thing to merge.
 *
 * ── What differs from the analyze envelope ────────────────────────────────
 * - The version field is `explain_schema_version`, compared against
 *   `config.explainSchemaVersion` — not `schema_version`, which every published
 *   build exact-matches and which must never move (§33).
 * - There is no `input_type` discriminant: this endpoint serves one shape. The
 *   closed allow-list below is what refuses an analyze body, which always
 *   carries `input_type` and `schema_version`, with 400 INVALID_REQUEST.
 * - The version is compared with `!==`, not parsed as a number: "2.0" and "1.0"
 *   are different contracts, and so is "1.00".
 *
 * ── The order of the checks ───────────────────────────────────────────────
 * Shape of the envelope, then the version (a client speaking another contract
 * cannot be assumed to mean anything else by its other fields), then the app
 * version, then ids, then the image. Cheap checks come before the decode.
 *
 * PRIVACY: no image byte parsed here is ever logged or attached to an error.
 * Every rejection is a fixed `ApiError` factory message.
 */

import type { RuntimeConfig } from "../config/runtime-config.ts";
import { isAppVersionSupported } from "../config/runtime-config.ts";
import { ApiError } from "../errors/api-error.ts";
import { isUuid } from "../http/request-id.ts";

/** The decoded explain-document request body (§33). */
export interface ExplainRequest {
  readonly sessionId: string;
  readonly installationId: string;
  readonly appVersion: string;
  readonly image: {
    /** Decoded bytes — the caller never sees the base64 string again. */
    readonly data: Uint8Array;
    readonly mimeType: string;
  };
}

const TOP_LEVEL_KEYS: ReadonlySet<string> = new Set([
  "explain_schema_version",
  "session_id",
  "installation_id",
  "app_version",
  "image",
]);

/** Photo formats the capture flow's rotate and crop steps may produce. */
const IMAGE_MIME_TYPES: ReadonlySet<string> = new Set(["image/jpeg", "image/png"]);

const BASE64_PATTERN = /^[A-Za-z0-9+/]+={0,2}$/;
const APP_VERSION_PATTERN = /^\d+\.\d+\.\d+$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Decodes and bounds-checks a base64 image payload.
 *
 * Rejects on shape before spending a decode on it: an empty string, one whose
 * length is not a multiple of 4, or one containing anything outside the base64
 * alphabet can never be valid, and the length check catches a grossly oversized
 * body before `atob` allocates for it.
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
 * Validates a decoded request body against the contract and the live config.
 *
 * @param body Whatever `JSON.parse` produced — not assumed to be an object.
 * @throws ApiError INVALID_REQUEST / UNSUPPORTED_SCHEMA / UNSUPPORTED_APP_VERSION
 */
export function parseExplainRequest(body: unknown, config: RuntimeConfig): ExplainRequest {
  if (!isRecord(body)) throw ApiError.invalidRequest();

  for (const key of Object.keys(body)) {
    if (!TOP_LEVEL_KEYS.has(key)) throw ApiError.invalidRequest();
  }

  const schemaVersion = body.explain_schema_version;
  if (typeof schemaVersion !== "string") throw ApiError.invalidRequest();
  if (schemaVersion !== config.explainSchemaVersion) throw ApiError.unsupportedSchema();

  // A version that does not match the pattern is a malformed field, not an old
  // app: telling someone to update an app that is already current would send
  // them nowhere.
  const appVersion = body.app_version;
  if (typeof appVersion !== "string" || !APP_VERSION_PATTERN.test(appVersion)) {
    throw ApiError.invalidRequest();
  }
  if (!isAppVersionSupported(appVersion, config.minimumAppVersion)) {
    throw ApiError.unsupportedAppVersion();
  }

  const sessionId = body.session_id;
  if (typeof sessionId !== "string" || !isUuid(sessionId)) throw ApiError.invalidRequest();

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

  return {
    sessionId: sessionId.toLowerCase(),
    installationId: installationId.toLowerCase(),
    appVersion,
    image: { data: decodeImageBase64(data, config.maxImageBytes), mimeType },
  };
}
