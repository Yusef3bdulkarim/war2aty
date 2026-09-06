/**
 * F06-T04 · JSON response construction.
 *
 * Every response from every endpoint goes through here, so the headers that
 * matter are applied once instead of being remembered per handler.
 *
 * Error bodies are NOT built here — that shape belongs to `ApiError` (F06-T05),
 * which serialises through {@link jsonResponse} like everything else.
 */

import { CORS_HEADERS } from "./cors.ts";
import { REQUEST_ID_HEADER } from "./request-id.ts";

export interface JsonResponseOptions {
  /** Defaults to 200. */
  readonly status?: number;
  /** Echoed back so the client can correlate a call with a server-side log. */
  readonly requestId?: string;
  /** Extra headers; these win over the defaults. */
  readonly headers?: Readonly<Record<string, string>>;
}

/**
 * Headers applied to every response.
 *
 * `no-store` is a privacy requirement, not a performance choice: an analysis
 * response describes someone's electricity bill or medical report, and it must
 * never sit in a proxy, a CDN, or a browser disk cache (§6, §7).
 *
 * `nosniff` stops a client from re-interpreting a JSON body as something else.
 */
const SECURITY_HEADERS: Readonly<Record<string, string>> = Object.freeze({
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
});

/**
 * Builds a JSON response with the standard headers.
 *
 * `null` status defaults to 200. Bodies are serialised with `JSON.stringify`,
 * so callers must pass plain data — never an `Error`, whose message could carry
 * provider internals.
 */
export function jsonResponse(
  body: unknown,
  options: JsonResponseOptions = {},
): Response {
  const { status = 200, requestId, headers = {} } = options;

  const merged: Record<string, string> = {
    ...CORS_HEADERS,
    ...SECURITY_HEADERS,
    ...headers,
  };

  if (requestId !== undefined) {
    merged[REQUEST_ID_HEADER] = requestId;
  }

  return new Response(JSON.stringify(body), { status, headers: merged });
}

/**
 * A response with no body — for statuses where a body is meaningless (204).
 * Still carries the correlation id and CORS headers.
 */
export function emptyResponse(
  status: number,
  requestId?: string,
): Response {
  const headers: Record<string, string> = { ...CORS_HEADERS };
  if (requestId !== undefined) {
    headers[REQUEST_ID_HEADER] = requestId;
  }

  return new Response(null, { status, headers });
}
