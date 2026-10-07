/**
 * F27-T12 · The Postgres-backed {@link ErrorReportStore}.
 *
 * Writes through `record_error_report`, never with a bare INSERT, for one
 * reason: the per-user daily ceiling has to be applied in the same statement
 * that writes the row. Counting in TypeScript and then inserting would race
 * with itself the moment a crash loop fires two reports at once, and a crash
 * loop is exactly when this code runs.
 *
 * Uses the service role: `error_reports` has RLS on with no policies and no
 * client grants (§26), like every other table here.
 */

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import type {
  ErrorReportInput,
  ErrorReportStore,
  RecordOutcome,
} from "./report-error-handler.ts";

const OUTCOMES: readonly string[] = ["recorded", "rate_limited"];

export function createSupabaseErrorReportStore(
  client: SupabaseClient,
): ErrorReportStore {
  return async (input: ErrorReportInput): Promise<RecordOutcome> => {
    const { data, error } = await client.rpc("record_error_report", {
      p_user_id: input.userId,
      p_error_code: input.errorCode,
      p_stage: input.stage,
      p_result_status: input.resultStatus,
      p_request_id: input.requestId,
      p_analysis_session_id: input.analysisSessionId,
      p_http_status: input.httpStatus,
      p_duration_ms: input.durationMs,
      p_app_version: input.appVersion,
      p_schema_version: input.schemaVersion,
    });

    if (error) throw error;

    const outcome = Array.isArray(data) ? data[0] : data;
    if (typeof outcome !== "string" || !OUTCOMES.includes(outcome)) {
      throw new Error("record_error_report returned an unusable result");
    }

    return outcome as RecordOutcome;
  };
}
