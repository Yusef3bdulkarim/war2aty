/**
 * F06-T13 · The endpoint boundary.
 *
 * Everything every endpoint must do regardless of what it does — preflight,
 * method check, correlation id, error serialisation, one access-log line —
 * happens here exactly once. A handler below this line may throw an
 * {@link ApiError} freely and never builds an error body itself.
 *
 * The other half of the point is testability: `Deno.serve` lives in each
 * function's `index.ts` and nothing else, so a handler is just
 * `Request → Response` and its status codes can be asserted without a stack,
 * a network, or a running edge runtime.
 */

import { ApiError, toApiError } from "../errors/api-error.ts";
import { logEvent } from "../observability/log.ts";
import { isPreflightRequest, preflightResponse } from "./cors.ts";
import { REQUEST_ID_HEADER, type RequestIdSource, resolveRequestId } from "./request-id.ts";

export interface RequestContext {
  readonly request: Request;
  /** Client-supplied when possible — that is what makes retries idempotent. */
  readonly requestId: string;
  readonly requestIdSource: RequestIdSource;
}

export type EndpointHandler = (context: RequestContext) => Promise<Response>;

export interface EndpointOptions {
  /** Appears in every log line as `fn`. Use the function's folder name. */
  readonly name: string;
  /** The single method this endpoint serves (§23). */
  readonly method: "GET" | "POST";
  readonly handle: EndpointHandler;
}

/**
 * Guarantees the correlation id is on the response even if a handler forgot it.
 * Rebuilding is safe here: the body stream has not been read.
 */
function withRequestId(response: Response, requestId: string): Response {
  if (response.headers.has(REQUEST_ID_HEADER)) return response;

  const headers = new Headers(response.headers);
  headers.set(REQUEST_ID_HEADER, requestId);

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export function createEndpoint(
  options: EndpointOptions,
): (request: Request) => Promise<Response> {
  const { name, method, handle } = options;

  return async (request: Request): Promise<Response> => {
    if (isPreflightRequest(request)) return preflightResponse();

    const { requestId, source } = resolveRequestId(request);
    const startedAt = Date.now();

    let response: Response;
    let errorCode: string | null = null;

    try {
      if (request.method !== method) {
        // 400 rather than 405: §31 is a closed enum with no method code, and
        // `additionalProperties: false` forbids inventing one. A client that
        // reaches here is malformed, which is exactly INVALID_REQUEST.
        throw ApiError.invalidRequest("Unsupported method for this endpoint.");
      }

      response = await handle({
        request,
        requestId,
        requestIdSource: source,
      });
    } catch (thrown) {
      // `toApiError` discards the message of anything that is not already an
      // ApiError — a driver or parser exception can quote the document.
      const apiError = toApiError(thrown);
      errorCode = apiError.code;
      response = apiError.toResponse(requestId);
    }

    logEvent("request", {
      fn: name,
      request_id: requestId,
      request_id_source: source,
      method: request.method,
      status: response.status,
      code: errorCode,
      duration_ms: Date.now() - startedAt,
    });

    return withRequestId(response, requestId);
  };
}
