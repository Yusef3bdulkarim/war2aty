/**
 * F06-T08 · Runtime configuration.
 *
 * Values an operator can change without shipping an app build: the daily
 * limit, the kill switch, the OCR cap, the minimum client version (§52).
 * Table-backed values come from `app_runtime_config`; timing comes from the
 * environment, because it sits alongside the AI credentials (§24).
 *
 * These defaults mirror `RuntimeConfig.defaults` in
 * `lib/core/config/runtime_config.dart`. When the app cannot reach the backend
 * it falls back to its own copy, so the two must not drift.
 */

export interface RuntimeConfig {
  /** Kill switch. `false` → analyze-document answers 503 ANALYSIS_DISABLED. */
  readonly analysisEnabled: boolean;
  readonly dailyLimit: number;
  readonly maxOcrCharacters: number;
  /** Clients below this are refused with 400 UNSUPPORTED_APP_VERSION. */
  readonly minimumAppVersion: string;
  /** Contract version the server speaks; requests must match. */
  readonly schemaVersion: string;
  /** Shown to the user during maintenance; `null` means normal operation. */
  readonly maintenanceMessage: string | null;
  /**
   * How long to wait on the AI. Env-sourced, not table-backed. Must stay below
   * the client's own timeout so the server gives up first, releases the slot
   * and answers 408 — rather than the client abandoning an analysis that still
   * counts against the quota.
   */
  readonly aiTimeoutSeconds: number;
}

export const DEFAULT_RUNTIME_CONFIG: RuntimeConfig = Object.freeze({
  analysisEnabled: true,
  dailyLimit: 3,
  maxOcrCharacters: 12000,
  minimumAppVersion: "1.0.0",
  schemaVersion: "1.0",
  maintenanceMessage: null,
  aiTimeoutSeconds: 25,
});

/** A `{ key, value }` row of `app_runtime_config`; `value` is JSONB. */
export interface RuntimeConfigRow {
  readonly key: string;
  readonly value: unknown;
}

function positiveInteger(value: unknown, fallback: number): number {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : Number.NaN;

  if (!Number.isFinite(parsed) || parsed < 1) return fallback;
  return Math.floor(parsed);
}

function nonEmptyString(value: unknown, fallback: string): string {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

/**
 * Reads the kill switch.
 *
 * Deliberately permissive about spelling — `true`, `"true"`, `1` all mean
 * enabled — because an operator editing this row by hand should not be able to
 * halt the service with a quoting mistake.
 *
 * An **absent** key means enabled (the documented default). A key that is
 * present but genuinely uninterpretable means DISABLED: the only reason to
 * touch this row is to stop analysis, so an unreadable value fails closed
 * rather than leaving the thing running that someone was trying to switch off.
 */
function killSwitch(value: unknown, keyPresent: boolean): boolean {
  if (!keyPresent) return DEFAULT_RUNTIME_CONFIG.analysisEnabled;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;

  if (typeof value === "string") {
    const normalised = value.trim().toLowerCase();
    if (["true", "1", "yes", "on"].includes(normalised)) return true;
    if (["false", "0", "no", "off"].includes(normalised)) return false;
  }

  return false;
}

/**
 * Builds the config from table rows, falling back per key.
 *
 * Per-key fallback is deliberate: one malformed row must not take the service
 * down. (A failure to READ the table at all is different — see
 * `supabase-runtime-config.ts`.) The daily limit falls back to the documented
 * default rather than to zero, since blocking every user is a worse answer to
 * a typo than briefly using 3; `evaluateDailyLimit` still fails closed on
 * anything nonsensical that reaches it.
 */
export function parseRuntimeConfig(
  rows: readonly RuntimeConfigRow[],
  environment: { get(key: string): string | undefined } = Deno.env,
): RuntimeConfig {
  const byKey = new Map(rows.map((row) => [row.key, row.value]));
  const has = (key: string) => byKey.has(key);
  const read = (key: string) => byKey.get(key);

  const maintenance = read("maintenance_message");

  return {
    analysisEnabled: killSwitch(read("analysis_enabled"), has("analysis_enabled")),
    dailyLimit: positiveInteger(
      read("daily_limit"),
      DEFAULT_RUNTIME_CONFIG.dailyLimit,
    ),
    maxOcrCharacters: positiveInteger(
      read("max_ocr_characters"),
      DEFAULT_RUNTIME_CONFIG.maxOcrCharacters,
    ),
    minimumAppVersion: nonEmptyString(
      read("minimum_app_version"),
      DEFAULT_RUNTIME_CONFIG.minimumAppVersion,
    ),
    schemaVersion: nonEmptyString(
      read("schema_version"),
      DEFAULT_RUNTIME_CONFIG.schemaVersion,
    ),
    // Only a non-empty string is a message; JSON null, "" and absence all mean
    // "operating normally".
    maintenanceMessage: typeof maintenance === "string" &&
        maintenance.trim().length > 0
      ? maintenance.trim()
      : null,
    aiTimeoutSeconds: positiveInteger(
      environment.get("AI_TIMEOUT_SECONDS"),
      DEFAULT_RUNTIME_CONFIG.aiTimeoutSeconds,
    ),
  };
}

// ── app version gate ──────────────────────────────────────────────────────

const VERSION_PATTERN = /^(\d+)\.(\d+)\.(\d+)$/;

/**
 * Compares two `major.minor.patch` versions numerically.
 *
 * String comparison would be wrong in the obvious way: `"1.10.0" < "1.9.0"`.
 *
 * @returns negative if `a < b`, 0 if equal, positive if `a > b`; `null` when
 * either side is not a well-formed version.
 */
export function compareVersions(a: string, b: string): number | null {
  const left = VERSION_PATTERN.exec(a.trim());
  const right = VERSION_PATTERN.exec(b.trim());
  if (left === null || right === null) return null;

  for (let part = 1; part <= 3; part += 1) {
    const difference = Number(left[part]) - Number(right[part]);
    if (difference !== 0) return difference;
  }
  return 0;
}

/**
 * Whether a client may be served (§29 rule 2).
 *
 * A malformed client version is refused: the value comes from the request, and
 * something that cannot be checked must not be waved through.
 */
export function isAppVersionSupported(
  appVersion: string,
  minimumAppVersion: string,
): boolean {
  const comparison = compareVersions(appVersion, minimumAppVersion);
  return comparison !== null && comparison >= 0;
}
