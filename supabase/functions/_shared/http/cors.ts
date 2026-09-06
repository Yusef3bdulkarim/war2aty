/**
 * F06-T04 · CORS headers and preflight handling.
 *
 * The MVP ships Android and iOS only, and native HTTP clients never send a
 * preflight — so nothing here is load-bearing today. It exists so a browser
 * client (or a `curl`-from-devtools debugging session) does not fail in a
 * confusing way, and so the allowed surface is written down explicitly rather
 * than being whatever the platform defaults to.
 *
 * `*` is safe for this API: authentication is a Bearer token, never a cookie.
 * A browser cannot silently attach credentials to a cross-origin call here, so
 * a hostile page still needs a JWT it has no way to obtain.
 */

/** Headers the app is allowed to send. */
const ALLOWED_REQUEST_HEADERS = [
  "authorization",
  "content-type",
  "apikey",
  "x-client-info",
  "x-request-id",
].join(", ");

/** Only what the three endpoints actually serve (§23). */
const ALLOWED_METHODS = "GET, POST, OPTIONS";

export const CORS_HEADERS: Readonly<Record<string, string>> = Object.freeze({
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": ALLOWED_REQUEST_HEADERS,
  "Access-Control-Allow-Methods": ALLOWED_METHODS,
  // Lets the client read the correlation id off the response.
  "Access-Control-Expose-Headers": "x-request-id",
  // Cache the preflight for a day so browsers stop re-asking.
  "Access-Control-Max-Age": "86400",
});

/** True when this is a CORS preflight rather than a real call. */
export function isPreflightRequest(request: Request): boolean {
  return request.method === "OPTIONS";
}

/**
 * Answers a preflight. 204 with no body — the headers are the whole point.
 */
export function preflightResponse(): Response {
  return new Response(null, { status: 204, headers: { ...CORS_HEADERS } });
}
