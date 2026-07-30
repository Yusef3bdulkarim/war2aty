/**
 * F06-T08 · Tests for runtime configuration.
 */

import { assertEquals } from "jsr:@std/assert@1";

import {
  compareVersions,
  DEFAULT_RUNTIME_CONFIG,
  isAppVersionSupported,
  parseRuntimeConfig,
  type RuntimeConfigRow,
} from "../../functions/_shared/config/runtime-config.ts";

/** Stands in for Deno.env so tests never depend on the real environment. */
function env(values: Record<string, string> = {}) {
  return { get: (key: string) => values[key] };
}

/** The rows the migration seeds. */
const SEEDED: RuntimeConfigRow[] = [
  { key: "daily_limit", value: 3 },
  { key: "analysis_enabled", value: true },
  { key: "max_ocr_characters", value: 12000 },
  { key: "minimum_app_version", value: "1.0.0" },
  { key: "schema_version", value: "1.0" },
  { key: "maintenance_message", value: null },
];

// ── happy path ────────────────────────────────────────────────────────────

Deno.test("the seeded rows parse to the documented defaults", () => {
  const config = parseRuntimeConfig(SEEDED, env());

  assertEquals(config.analysisEnabled, true);
  assertEquals(config.dailyLimit, 3);
  assertEquals(config.maxOcrCharacters, 12000);
  assertEquals(config.minimumAppVersion, "1.0.0");
  assertEquals(config.schemaVersion, "1.0");
  assertEquals(config.maintenanceMessage, null);
});

Deno.test("the parsed defaults match the Flutter fallback copy", () => {
  // lib/core/config/runtime_config.dart holds the same values for offline use;
  // drift between the two would change behaviour depending on connectivity.
  const config = parseRuntimeConfig(SEEDED, env());

  assertEquals(config.dailyLimit, DEFAULT_RUNTIME_CONFIG.dailyLimit);
  assertEquals(config.maxOcrCharacters, DEFAULT_RUNTIME_CONFIG.maxOcrCharacters);
  assertEquals(config.schemaVersion, DEFAULT_RUNTIME_CONFIG.schemaVersion);
  assertEquals(
    config.minimumAppVersion,
    DEFAULT_RUNTIME_CONFIG.minimumAppVersion,
  );
});

Deno.test("an empty table yields the defaults rather than failing", () => {
  const config = parseRuntimeConfig([], env());

  assertEquals(config.analysisEnabled, true);
  assertEquals(config.dailyLimit, 3);
});

Deno.test("operator changes take effect without an app release", () => {
  const config = parseRuntimeConfig([
    { key: "daily_limit", value: 10 },
    { key: "max_ocr_characters", value: 20000 },
    { key: "minimum_app_version", value: "2.1.0" },
  ], env());

  assertEquals(config.dailyLimit, 10);
  assertEquals(config.maxOcrCharacters, 20000);
  assertEquals(config.minimumAppVersion, "2.1.0");
});

// ── the kill switch ───────────────────────────────────────────────────────

Deno.test("the kill switch stops analysis when set to false", () => {
  const config = parseRuntimeConfig(
    [{ key: "analysis_enabled", value: false }],
    env(),
  );

  assertEquals(config.analysisEnabled, false);
});

Deno.test("the kill switch tolerates hand-edited spellings", () => {
  // An operator typing "false" instead of false must still stop the service.
  for (const value of ["false", "FALSE", " off ", "no", "0", 0]) {
    assertEquals(
      parseRuntimeConfig([{ key: "analysis_enabled", value }], env())
        .analysisEnabled,
      false,
      `${JSON.stringify(value)} should disable`,
    );
  }

  for (const value of ["true", "TRUE", " on ", "yes", "1", 1]) {
    assertEquals(
      parseRuntimeConfig([{ key: "analysis_enabled", value }], env())
        .analysisEnabled,
      true,
      `${JSON.stringify(value)} should enable`,
    );
  }
});

Deno.test("an uninterpretable kill switch fails closed", () => {
  // Present but meaningless: the only reason to touch this row is to stop
  // analysis, so we must not leave running the thing someone tried to switch
  // off. Absence is different — that is the documented "enabled" default.
  for (const value of [{ nonsense: true }, [], "maybe"]) {
    assertEquals(
      parseRuntimeConfig([{ key: "analysis_enabled", value }], env())
        .analysisEnabled,
      false,
      `${JSON.stringify(value)} should disable`,
    );
  }

  assertEquals(parseRuntimeConfig([], env()).analysisEnabled, true);
});

// ── malformed rows ────────────────────────────────────────────────────────

Deno.test("a malformed daily limit falls back instead of blocking everyone", () => {
  for (const value of ["abc", null, -5, 0, {}]) {
    assertEquals(
      parseRuntimeConfig([{ key: "daily_limit", value }], env()).dailyLimit,
      3,
      `${JSON.stringify(value)} should fall back`,
    );
  }
});

Deno.test("a numeric string limit is accepted", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "daily_limit", value: "5" }], env()).dailyLimit,
    5,
  );
});

Deno.test("a fractional limit is floored", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "daily_limit", value: 4.9 }], env()).dailyLimit,
    4,
  );
});

Deno.test("a blank version falls back to the default", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "minimum_app_version", value: "  " }], env())
      .minimumAppVersion,
    "1.0.0",
  );
});

Deno.test("unknown keys are ignored", () => {
  const config = parseRuntimeConfig(
    [...SEEDED, { key: "future_flag", value: "whatever" }],
    env(),
  );

  assertEquals(config.dailyLimit, 3);
});

// ── maintenance message ───────────────────────────────────────────────────

Deno.test("a maintenance message is surfaced when set", () => {
  const config = parseRuntimeConfig(
    [{ key: "maintenance_message", value: "التطبيق تحت الصيانة" }],
    env(),
  );

  assertEquals(config.maintenanceMessage, "التطبيق تحت الصيانة");
});

Deno.test("null, blank and absent all mean operating normally", () => {
  for (
    const rows of [
      [{ key: "maintenance_message", value: null }],
      [{ key: "maintenance_message", value: "   " }],
      [],
    ]
  ) {
    assertEquals(parseRuntimeConfig(rows, env()).maintenanceMessage, null);
  }
});

// ── env-sourced timing ────────────────────────────────────────────────────

Deno.test("the AI timeout comes from the environment", () => {
  assertEquals(
    parseRuntimeConfig([], env({ AI_TIMEOUT_SECONDS: "30" })).aiTimeoutSeconds,
    30,
  );
});

Deno.test("a missing or bad AI timeout falls back to 25s", () => {
  // Must stay under the client's 30s, or the client abandons an analysis the
  // server still counts.
  assertEquals(parseRuntimeConfig([], env()).aiTimeoutSeconds, 25);
  assertEquals(
    parseRuntimeConfig([], env({ AI_TIMEOUT_SECONDS: "nonsense" }))
      .aiTimeoutSeconds,
    25,
  );
});

// ── version comparison ────────────────────────────────────────────────────

Deno.test("compareVersions orders numerically, not lexically", () => {
  // The classic bug: "1.10.0" sorts before "1.9.0" as a string.
  assertEquals(compareVersions("1.10.0", "1.9.0")! > 0, true);
  assertEquals(compareVersions("1.0.0", "1.0.0"), 0);
  assertEquals(compareVersions("2.0.0", "1.99.99")! > 0, true);
  assertEquals(compareVersions("1.0.9", "1.0.10")! < 0, true);
});

Deno.test("compareVersions rejects malformed input", () => {
  assertEquals(compareVersions("1.0", "1.0.0"), null);
  assertEquals(compareVersions("v1.0.0", "1.0.0"), null);
  assertEquals(compareVersions("1.0.0-beta", "1.0.0"), null);
  assertEquals(compareVersions("", "1.0.0"), null);
});

Deno.test("a client at or above the minimum is served", () => {
  assertEquals(isAppVersionSupported("1.0.0", "1.0.0"), true);
  assertEquals(isAppVersionSupported("1.2.0", "1.0.0"), true);
  assertEquals(isAppVersionSupported("1.10.0", "1.9.0"), true);
});

Deno.test("a client below the minimum is refused", () => {
  assertEquals(isAppVersionSupported("0.9.0", "1.0.0"), false);
  assertEquals(isAppVersionSupported("1.0.0", "1.0.1"), false);
});

Deno.test("a malformed client version is refused, not waved through", () => {
  // It comes from the request; what cannot be checked must not pass.
  assertEquals(isAppVersionSupported("garbage", "1.0.0"), false);
  assertEquals(isAppVersionSupported("", "1.0.0"), false);
  assertEquals(isAppVersionSupported("999", "1.0.0"), false);
});
