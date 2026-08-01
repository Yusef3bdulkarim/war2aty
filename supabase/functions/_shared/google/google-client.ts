/**
 * F13-T07 · Google Document AI transport.
 *
 * The only place that speaks HTTP to Google. Two calls per analysis: exchange
 * a self-signed service-account JWT for a short-lived OAuth2 access token,
 * then call the processor's *synchronous* `process` endpoint once with the
 * whole document (§ Locked decisions #4) and return the extracted text.
 * Merging this with Azure's result is T08's job, same split as
 * `azure-client.ts` (T04) vs its own T06 extension.
 *
 * Per the locked decision (§3), only the synchronous `process` API is ever
 * called. Document AI's `batchProcess` is asynchronous and writes results to
 * a caller-provided GCS bucket rather than returning them inline — using it
 * would mean a document image sitting in cloud storage, which this project
 * does not do regardless of document size. A whole-document resend (decision
 * #4) is always within the sync endpoint's payload limit.
 *
 * Auth is a hand-signed RS256 JWT exchanged via the standard OAuth2
 * service-account flow (no Google client library — same "no SDK" precedent as
 * `groq-client.ts`/`azure-client.ts`; `crypto.subtle` already does everything
 * needed). The JWT itself never touches the network as anything but the
 * `assertion` parameter of the token exchange, and is never logged.
 *
 * PRIVACY (§7, §51): no OCR text, prompt, or key is ever logged. Error paths
 * discard the provider's response body without reading it as text.
 */

import { ApiError } from "../errors/api-error.ts";
import type { GoogleDocumentAiOptions } from "./google-config.ts";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const TOKEN_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer";
const DOCUMENT_AI_SCOPE = "https://www.googleapis.com/auth/cloud-platform";

/** Google requires the assertion to expire within one hour of issuance. */
const JWT_LIFETIME_SECONDS = 3600;

export interface GoogleDocumentAiResult {
  /** The full extracted text, in reading order. */
  readonly content: string;
}

export interface GoogleDocumentAiClientOptions extends GoogleDocumentAiOptions {
  /** Wall-clock budget for the token exchange + process call combined. */
  readonly timeoutSeconds: number;
  /** Injected so tests never touch the network. */
  readonly fetchImpl?: typeof fetch;
}

export type GoogleDocumentAiClient = (
  image: Uint8Array,
  mimeType: string,
) => Promise<GoogleDocumentAiResult>;

// ── base64 helpers ──────────────────────────────────────────────────────────
// Deno ships no base64 global beyond ASCII-only `atob`/`btoa`; both the PEM
// key and the image bytes are raw binary, so the string<->bytes bridging has
// to be done a chunk at a time to avoid blowing `String.fromCharCode`'s
// argument limit on a multi-megabyte image.

const BASE64_CHUNK_SIZE = 0x8000;

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += BASE64_CHUNK_SIZE) {
    binary += String.fromCharCode(...bytes.subarray(i, i + BASE64_CHUNK_SIZE));
  }
  return btoa(binary);
}

function base64UrlEncode(bytes: Uint8Array): string {
  return base64Encode(bytes)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64Decode(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// ── JWT signing ──────────────────────────────────────────────────────────

/** Strips the PEM armor and decodes the PKCS8 body into an importable key. */
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  return await crypto.subtle.importKey(
    "pkcs8",
    // Cast: the lib types want an ArrayBuffer-backed view; a plain
    // Uint8Array's buffer is typed as the more general ArrayBufferLike. Same
    // mismatch, same fix, as `azure-client.ts`'s fetch body cast.
    base64Decode(body) as unknown as BufferSource,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/**
 * Builds a self-signed JWT asserting this service account, scoped to
 * Document AI, addressed at Google's token endpoint — the standard
 * OAuth2 service-account (RFC 7523) bearer-assertion flow.
 */
async function buildSignedAssertion(
  options: GoogleDocumentAiOptions,
  nowSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: options.clientEmail,
    scope: DOCUMENT_AI_SCOPE,
    aud: TOKEN_URL,
    iat: nowSeconds,
    exp: nowSeconds + JWT_LIFETIME_SECONDS,
  };

  const signingInput = `${base64UrlEncode(encoder.encode(JSON.stringify(header)))}.` +
    base64UrlEncode(encoder.encode(JSON.stringify(claims)));

  const key = await importPrivateKey(options.privateKey);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

// ── transport ────────────────────────────────────────────────────────────

/** Maps a non-2xx provider response to an `ApiError`. The body is never read. */
function errorForStatus(status: number): ApiError {
  if (status === 429) return ApiError.aiRateLimited();
  return ApiError.analysisFailed();
}

function mapTransportError(thrown: unknown): ApiError {
  if (thrown instanceof DOMException && thrown.name === "TimeoutError") {
    return ApiError.timeout();
  }
  return ApiError.analysisFailed();
}

async function discard(response: Response): Promise<void> {
  await response.body?.cancel();
}

interface TokenResponseBody {
  access_token?: string;
}

async function exchangeAssertionForToken(
  fetchImpl: typeof fetch,
  assertion: string,
  signal: AbortSignal,
): Promise<string> {
  let response: Response;
  try {
    response = await fetchImpl(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: TOKEN_GRANT_TYPE, assertion }),
      signal,
    });
  } catch (thrown) {
    throw mapTransportError(thrown);
  }

  if (!response.ok) {
    await discard(response);
    throw errorForStatus(response.status);
  }

  let body: TokenResponseBody;
  try {
    body = await response.json();
  } catch {
    throw ApiError.analysisFailed();
  }

  if (typeof body.access_token !== "string" || body.access_token.length === 0) {
    // A 200 with no usable token is still a failure to authenticate.
    throw ApiError.analysisFailed();
  }

  return body.access_token;
}

interface ProcessResponseBody {
  document?: { text?: string };
}

function processUrl(options: GoogleDocumentAiOptions): string {
  const { projectId, location, processorId } = options;
  return `https://${location}-documentai.googleapis.com/v1/projects/${projectId}` +
    `/locations/${location}/processors/${processorId}:process`;
}

/**
 * Builds a client bound to a service account and processor.
 *
 * The timeout spans both network calls — token exchange and process — as one
 * budget, same reasoning as `azure-client.ts`: a hung provider must not hold
 * the caller's reserved analysis slot indefinitely.
 */
export function createGoogleDocumentAiClient(
  options: GoogleDocumentAiClientOptions,
): GoogleDocumentAiClient {
  const { timeoutSeconds, fetchImpl = fetch, ...credentials } = options;
  const url = processUrl(credentials);

  return async (
    image: Uint8Array,
    mimeType: string,
  ): Promise<GoogleDocumentAiResult> => {
    const signal = AbortSignal.timeout(
      Math.max(1, Math.floor(timeoutSeconds)) * 1000,
    );

    const assertion = await buildSignedAssertion(
      credentials,
      Math.floor(Date.now() / 1000),
    );
    const accessToken = await exchangeAssertionForToken(
      fetchImpl,
      assertion,
      signal,
    );

    let response: Response;
    try {
      response = await fetchImpl(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          rawDocument: { content: base64Encode(image), mimeType },
        }),
        signal,
      });
    } catch (thrown) {
      throw mapTransportError(thrown);
    }

    if (!response.ok) {
      await discard(response);
      throw errorForStatus(response.status);
    }

    let body: ProcessResponseBody;
    try {
      body = await response.json();
    } catch {
      throw ApiError.analysisFailed();
    }

    const content = body.document?.text;
    if (typeof content !== "string" || content.length === 0) {
      // A well-formed response carrying no text is still unusable.
      throw ApiError.analysisFailed();
    }

    return { content };
  };
}
