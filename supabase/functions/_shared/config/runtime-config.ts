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
  /**
   * Cross-user cap on total AI-provider calls per Cairo day (F13-T02).
   * `null` means UNLIMITED — the breaker is off.
   *
   * Server-side only, and deliberately absent from the Flutter
   * `RuntimeConfig`: it is an operational spend valve, not a product rule the
   * app should show, predict or count against.
   *
   * Note the fail direction is the OPPOSITE of {@link dailyLimit}. That one is
   * a mandatory product decision, so an unreadable value falls back to a real
   * number. This one is an optional safety valve dark-launched with no cap
   * configured, so anything unreadable means "off" — a typo in this row must
   * not block every user of the service.
   */
  readonly globalDailyCallCap: number | null;
  /**
   * Whether the online Azure/Google image pipeline may run at all (F13-T03).
   *
   * Dark-launched: `false` until an operator explicitly flips it, so every
   * task before the pipeline is actually wired (T04–T17) ships with it
   * inert. Once wired, `false` means the offline Tesseract path runs
   * unconditionally, same as today.
   */
  readonly azureOcrEnabled: boolean;
  readonly maxOcrCharacters: number;
  /**
   * Upper bound on a decoded `image.data` payload, in bytes (F13-T09).
   *
   * Only enforced on the image-intake request shape — the text shape has no
   * image field to bound. Sized around a compressed phone-camera photo after
   * the existing capture-quality gate (F04), with headroom; a base64 body
   * this large is still cheap to reject before it is ever handed to Azure.
   */
  readonly maxImageBytes: number;
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
  // Dark by default (F13-T03): no cap until an operator sets one, so today's
  // Groq-only pipeline behaves exactly as it did before this key existed.
  globalDailyCallCap: null,
  // Dark by default (F13-T03): off until an operator explicitly enables it.
  azureOcrEnabled: false,
  maxOcrCharacters: 12000,
  // ~8MB decoded — comfortably above a compressed capture-quality-gated photo,
  // small enough that an oversized body is still cheap to reject on parse.
  maxImageBytes: 8_000_000,
  minimumAppVersion: "1.0.0",
  // F13-T09: bumped for the image-intake request shape, `rawValue` on
  // dates/amounts, and the new phones[]/references[] response arrays.
  schemaVersion: "2.0",
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

/**
 * A cap that may be switched off, for values where "no limit" is a valid state.
 *
 * Everything unusable — absent, `null`, `0`, negative, fractional-below-one,
 * `"abc"`, an object — reads as `null`/unlimited. That is the whole point:
 * unlike {@link positiveInteger}, there is no safe number to fall back to, and
 * inventing one would impose a limit nobody configured.
 */
function nullablePositiveInteger(value: unknown): number | null {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : Number.NaN;

  if (!Number.isFinite(parsed) || parsed < 1) return null;
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
 * Reads an opt-in feature flag — the mirror image of {@link killSwitch}.
 *
 * A kill switch's only reason to be touched is to stop something already
 * running, so it fails toward "stopped". A brand-new, dark-launched provider
 * integration (F13-T03) is the opposite: nobody has approved it as safe to
 * call yet, so an **absent** key, a genuinely uninterpretable value, AND the
 * documented "off" spellings all mean disabled. Only an explicit
 * `true`/`"true"`/`1`/`"on"` turns it on.
 */
function optInFlag(value: unknown, keyPresent: boolean): boolean {
  if (!keyPresent) return false;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value === 1;

  if (typeof value === "string") {
    return ["true", "1", "yes", "on"].includes(value.trim().toLowerCase());
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
    globalDailyCallCap: nullablePositiveInteger(read("global_daily_call_cap")),
    azureOcrEnabled: optInFlag(
      read("azure_ocr_enabled"),
      has("azure_ocr_enabled"),
    ),
    maxOcrCharacters: positiveInteger(
      read("max_ocr_characters"),
      DEFAULT_RUNTIME_CONFIG.maxOcrCharacters,
    ),
    maxImageBytes: positiveInteger(
      read("max_image_bytes"),
      DEFAULT_RUNTIME_CONFIG.maxImageBytes,
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
