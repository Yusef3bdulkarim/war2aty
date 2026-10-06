/**
 * F27-T12 · The `report-error` handler.
 *
 * Production ran on a no-op log sink, so nothing that broke in the field left
 * a trace anywhere (F27-H1). This is the other end of the fix: the app posts
 * an allowlisted code and envelope, and we keep it in our own table.
 *
 * ── What it is not ──────────────────────────────────────────────────────
 *
 * Not a crash reporter. There is no stack trace, no exception message, no
 * breadcrumb trail — Q13 chose this shape precisely because a third-party
 * reporter could not be shown never to receive document content, and §7 does
 * not allow "probably scrubbed". What this gives is counts by code, by stage
 * and by app version: enough to know *that* something is broken and roughly
 * where, never enough to read anyone's paper.
 *
 * ── Why it answers 202 even when it stores nothing ───────────────────────
 *
 * The store applies a per-user daily ceiling (see the migration). Past it the
 * row is dropped, and the response is still 202: the client is not misbehaving
 * and has nothing to do differently, and a 429 would only teach the sink to
 * retry. Whether a report was kept is recorded in the function's own log line,
 * which is where an operator looks.
 */

import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import { ApiError, apiErrorForAuthFailure } from "../errors/api-error.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { emptyResponse } from "../http/response.ts";
import { logEvent } from "../observability/log.ts";
import { parseErrorReportRequest } from "./error-report-request.ts";

/** Outcome of trying to keep one report. */
export type RecordOutcome = "recorded" | "rate_limited";

export interface ErrorReportInput {
  readonly userId: string;
  readonly errorCode: string;
  readonly stage: string | null;
  readonly resultStatus: string | null;
  readonly requestId: string | null;
  readonly analysisSessionId: string | null;
  readonly httpStatus: number | null;
  readonly durationMs: number | null;
  readonly appVersion: string | null;
  readonly schemaVersion: string | null;
}

export type ErrorReportStore = (
  input: ErrorReportInput,
) => Promise<RecordOutcome>;

export interface ReportErrorDependencies {
  readonly verifyToken: TokenVerifier;
  readonly record: ErrorReportStore;
}

export function createReportErrorHandler(
  dependencies: ReportErrorDependencies,
): EndpointHandler {
  const { verifyToken, record } = dependencies;

  return async ({ request, requestId }): Promise<Response> => {
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      // The parse error quotes what it choked on. Discarded unread (§51).
      throw ApiError.invalidRequest();
    }

    const report = parseErrorReportRequest(rawBody);

    // The user comes from the verified token, never the body: a caller must
    // not be able to file reports against somebody else's identity.
    const outcome = await record({
      userId: auth.user.id,
      errorCode: report.errorCode,
      stage: report.stage,
      resultStatus: report.resultStatus,
      requestId: report.requestId,
      analysisSessionId: report.analysisSessionId,
      httpStatus: report.httpStatus,
      durationMs: report.durationMs,
      appVersion: report.appVersion,
      schemaVersion: report.schemaVersion,
    });

    // The client's reported code is logged, which is safe for the same reason
    // the column is: it is one of a closed set of our own identifiers.
    logEvent("error_report", {
      request_id: requestId,
      outcome,
      client_error_code: report.errorCode,
      stage: report.stage,
      app_version: report.appVersion,
    });

    return emptyResponse(202, requestId);
  };
}
