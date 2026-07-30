/**
 * F06-T05 · `ApiError` — the only way an endpoint reports failure.
 *
 * Handlers throw one of these; the endpoint boundary turns it into the §31
 * body via {@link ApiError.toResponse}. Nothing else constructs error JSON, so
 * the wire shape stays in one place.
 *
 * PRIVACY (§7, §51): `message` is a fixed English string chosen from the
 * factories below. It is never built from OCR text, candidate values, AI output
 * or a caught exception's message — any of which could carry the contents of
 * someone's document. The client never displays it; it derives Arabic copy from
 * `code` instead.
 */

import type { AuthFailureReason } from "../auth/require-user.ts";
import { jsonResponse } from "../http/response.ts";
import { type ErrorCode, httpStatusForErrorCode } from "./error-codes.ts";

/** Code-specific payload. §31 defines only `reset_at`, for the daily limit. */
export interface ErrorDetails {
  /** Cairo-midnight ISO-8601 when the quota resets. */
  readonly reset_at?: string;
}

/** The §31 error envelope, exactly — no extra properties are permitted. */
export interface ErrorBody {
  readonly error: {
    readonly code: ErrorCode;
    readonly message: string;
    readonly details?: ErrorDetails;
  };
}

export class ApiError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details?: ErrorDetails;

  constructor(code: ErrorCode, message: string, details?: ErrorDetails) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = httpStatusForErrorCode(code);
    this.details = details;
  }

  /** Serialises to the §31 body. `details` is omitted when absent. */
  toBody(): ErrorBody {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details === undefined ? {} : { details: this.details }),
      },
    };
  }

  toResponse(requestId?: string): Response {
    return jsonResponse(this.toBody(), { status: this.status, requestId });
  }

  // ── Factories ───────────────────────────────────────────────────────────
  // Fixed messages, so no call site can accidentally interpolate document
  // content into a response body.

  static invalidRequest(message = "Malformed or incomplete request."): ApiError {
    return new ApiError("INVALID_REQUEST", message);
  }

  static unsupportedSchema(): ApiError {
    return new ApiError("UNSUPPORTED_SCHEMA", "Unsupported schema version.");
  }

  static unsupportedAppVersion(): ApiError {
    return new ApiError(
      "UNSUPPORTED_APP_VERSION",
      "App version is below the supported minimum.",
    );
  }

  static unauthorized(): ApiError {
    return new ApiError("UNAUTHORIZED", "Missing or invalid credentials.");
  }

  static timeout(): ApiError {
    return new ApiError("TIMEOUT", "Analysis exceeded the time limit.");
  }

  /**
   * @param resetAt Cairo-midnight ISO-8601. The client shows the user when they
   * can try again, so omitting it degrades the message to a vague failure.
   */
  static dailyLimitReached(resetAt: string): ApiError {
    return new ApiError(
      "DAILY_LIMIT_REACHED",
      "Daily analysis limit reached.",
      { reset_at: resetAt },
    );
  }

  static aiRateLimited(): ApiError {
    return new ApiError("AI_RATE_LIMITED", "AI provider rate limit reached.");
  }

  /** The AI answered, but with output we could not use (§48 INVALID_AI_RESPONSE). */
  static analysisFailed(): ApiError {
    return new ApiError("ANALYSIS_FAILED", "Analysis produced unusable output.");
  }

  static internalError(): ApiError {
    return new ApiError("INTERNAL_ERROR", "Unexpected server error.");
  }

  static analysisDisabled(): ApiError {
    return new ApiError("ANALYSIS_DISABLED", "Analysis is temporarily disabled.");
  }
}

/**
 * Normalises anything thrown into an `ApiError`.
 *
 * A non-`ApiError` becomes a generic INTERNAL_ERROR and its message is
 * DISCARDED — an exception from a driver, a JSON parser, or the AI client can
 * quote the payload that caused it, and that payload is the user's document.
 */
export function toApiError(thrown: unknown): ApiError {
  return thrown instanceof ApiError ? thrown : ApiError.internalError();
}

/**
 * Maps an authorization failure (F06-T03) onto the wire.
 *
 * The distinction matters: only the caller's own mistakes are 401. When the
 * auth service could not be reached we answer 500, because telling a user they
 * are "not signed in" during an outage sends them hunting for a login screen
 * this app does not have.
 */
export function apiErrorForAuthFailure(reason: AuthFailureReason): ApiError {
  switch (reason) {
    case "missing_token":
    case "invalid_token":
      return ApiError.unauthorized();
    case "verification_failed":
      return ApiError.internalError();
  }
}
