/**
 * F27-T12 · `POST /functions/v1/report-error` — production error reporting.
 *
 * Wiring only, like `get-usage`: the service-role client is built once per
 * worker so a missing environment variable throws at startup rather than
 * becoming a puzzling 500 on every call.
 */

import { createSupabaseTokenVerifier } from "../_shared/auth/supabase-token-verifier.ts";
import { createEndpoint } from "../_shared/http/endpoint.ts";
import { createReportErrorHandler } from "../_shared/reports/report-error-handler.ts";
import { createSupabaseErrorReportStore } from "../_shared/reports/supabase-error-report-store.ts";
import { createServiceRoleClient } from "../_shared/usage/supabase-usage-store.ts";

const serviceClient = createServiceRoleClient();

Deno.serve(
  createEndpoint({
    name: "report-error",
    method: "POST",
    handle: createReportErrorHandler({
      verifyToken: createSupabaseTokenVerifier(),
      record: createSupabaseErrorReportStore(serviceClient),
    }),
  }),
);
