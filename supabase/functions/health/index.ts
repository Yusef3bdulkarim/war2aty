/**
 * F06-T13 · `GET /functions/v1/health` — liveness probe.
 *
 * The only unauthenticated endpoint (`verify_jwt = false` in config.toml), so
 * it is deliberately the dullest thing in the codebase: a fixed body and a
 * timestamp.
 *
 * It does NOT read the database or the runtime config. Two reasons: an
 * unauthenticated endpoint that does database work is a free lever for anyone
 * who can reach the URL, and a probe that fails because a table is slow tells
 * an operator the wrong thing. This answers exactly one question — "is the
 * edge runtime serving?" — which is what a health check is for.
 *
 * It returns no secret, no config value and no count. Nothing here reveals
 * anything about a user or a document.
 */

import { createEndpoint } from "../_shared/http/endpoint.ts";
import { jsonResponse } from "../_shared/http/response.ts";

Deno.serve(
  createEndpoint({
    name: "health",
    method: "GET",
    handle: ({ requestId }) =>
      Promise.resolve(
        jsonResponse(
          { status: "ok", time: new Date().toISOString() },
          { requestId },
        ),
      ),
  }),
);
