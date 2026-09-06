/**
 * F06-T04 · Request correlation id.
 *
 * This is not just a logging nicety. The same id becomes the primary key of
 * `analysis_attempts` (F06-T02), which is what makes a retry idempotent: a
 * client that resends a request under the same id collides on the PK instead
 * of consuming a second slot from its 3-per-day quota.
 *
 * That only works when the id comes FROM the client. A server-generated id is
 * fresh on every call, so a retry would look like a brand-new analysis — hence
 * {@link ResolvedRequestId.source}, so the caller can tell the two apart
 * instead of silently losing idempotency.
 *
 * PRIVACY: the id is a random uuid with no link to the device or the document,
 * so it is safe to log — unlike anything else in the request (§7).
 */

export const REQUEST_ID_HEADER = "x-request-id";

/** Where the id came from — decides whether retries can be idempotent. */
export type RequestIdSource = "client" | "generated";

export interface ResolvedRequestId {
  /** Lower-cased uuid, ready to use as the `analysis_attempts` key. */
  readonly requestId: string;
  readonly source: RequestIdSource;
}

// Any RFC 4122 uuid shape. Deliberately not pinned to v4: the column type is
// `uuid`, and rejecting a valid uuid over its version byte would break clients
// for no security gain.
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** True when `value` is a syntactically valid uuid. */
export function isUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

/**
 * Reads the client's request id, or mints one.
 *
 * A malformed id is treated as absent rather than as an error: the header is a
 * correlation aid, and failing the whole analysis over a bad one would be a
 * worse outcome than losing idempotency for that call. The `generated` source
 * is what records that this happened.
 */
export function resolveRequestId(request: Request): ResolvedRequestId {
  const header = request.headers.get(REQUEST_ID_HEADER);

  if (header !== null) {
    const candidate = header.trim().toLowerCase();
    if (isUuid(candidate)) {
      return { requestId: candidate, source: "client" };
    }
  }

  return { requestId: crypto.randomUUID(), source: "generated" };
}
