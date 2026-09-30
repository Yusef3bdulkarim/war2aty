/**
 * F20-T11 · The analysis chain's two timing knobs, from the environment.
 *
 * Both are optional: when unset, the chain uses the values F20-T09 set from
 * the benchmark's p95s (`DEFAULT_ATTEMPT_CAP_MS`, `DEFAULT_MIN_FALLBACK_MS`).
 * A value that is SET but unusable is a deploy fault, and throws naming the
 * variable only. `analyze-document` reads these before it reserves a slot, so
 * that fault never costs the user an analysis (matrix row A8).
 *
 * The request's overall budget is not here: it is `aiTimeoutSeconds` from
 * runtime config, which an operator can change without a redeploy.
 */

import { DEFAULT_ATTEMPT_CAP_MS, DEFAULT_MIN_FALLBACK_MS } from "./fallback-provider.ts";

export interface ChainTiming {
  /** The longest one attempt may run, in milliseconds. */
  readonly attemptCapMs: number;
  /** The least time left worth starting the fallback with, in milliseconds. */
  readonly minFallbackMs: number;
}

/** A positive, finite number, or `null` when the variable is unset or blank. */
function positiveNumber(name: string, raw: string | undefined): number | null {
  const trimmed = raw?.trim() ?? "";
  if (trimmed === "") return null;
  const value = Number(trimmed);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${name} must be a positive number.`);
  }
  return value;
}

/**
 * Reads `AI_ATTEMPT_TIMEOUT_SECONDS` and `MIN_FALLBACK_MS`.
 *
 * @throws when either is set to something that is not a positive number.
 */
export function chainTimingFromEnv(
  read: (name: string) => string | undefined = (name) => Deno.env.get(name),
): ChainTiming {
  const capSeconds = positiveNumber(
    "AI_ATTEMPT_TIMEOUT_SECONDS",
    read("AI_ATTEMPT_TIMEOUT_SECONDS"),
  );
  const minFallbackMs = positiveNumber("MIN_FALLBACK_MS", read("MIN_FALLBACK_MS"));

  return {
    attemptCapMs: capSeconds === null ? DEFAULT_ATTEMPT_CAP_MS : Math.round(capSeconds * 1000),
    minFallbackMs: minFallbackMs === null ? DEFAULT_MIN_FALLBACK_MS : Math.round(minFallbackMs),
  };
}
