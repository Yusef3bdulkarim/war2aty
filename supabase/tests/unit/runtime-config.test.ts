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
  // F13-T09 bumped this; the migration that seeded "1.0" is followed by one
  // that updates it to "2.0" (20260801120000_bump_schema_version_v2.sql).
  { key: "schema_version", value: "2.0" },
  { key: "maintenance_message", value: null },
];

// ── happy path ────────────────────────────────────────────────────────────

Deno.test("the seeded rows parse to the documented defaults", () => {
  const config = parseRuntimeConfig(SEEDED, env());

  assertEquals(config.analysisEnabled, true);
  assertEquals(config.dailyLimit, 3);
  assertEquals(config.maxOcrCharacters, 12000);
  assertEquals(config.minimumAppVersion, "1.0.0");
  assertEquals(config.schemaVersion, "2.0");
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

// ── the global capacity breaker (F13-T02) ─────────────────────────────────

Deno.test("no global cap key means unlimited, not zero", () => {
  // The breaker is dark-launched: before an operator sets a number it must be
  // completely inert. A 0 here would block every request in production.
  assertEquals(parseRuntimeConfig(SEEDED, env()).globalDailyCallCap, null);
  assertEquals(parseRuntimeConfig([], env()).globalDailyCallCap, null);
  assertEquals(DEFAULT_RUNTIME_CONFIG.globalDailyCallCap, null);
});

Deno.test("an operator can set the global cap without an app release", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "global_daily_call_cap", value: 500 }], env())
      .globalDailyCallCap,
    500,
  );
  assertEquals(
    parseRuntimeConfig([{ key: "global_daily_call_cap", value: "500" }], env())
      .globalDailyCallCap,
    500,
  );
  assertEquals(
    parseRuntimeConfig([{ key: "global_daily_call_cap", value: 500.9 }], env())
      .globalDailyCallCap,
    500,
  );
});

Deno.test("a malformed global cap fails OPEN, the opposite of daily_limit", () => {
  // This is the asymmetry worth pinning. daily_limit is a mandatory product
  // rule, so a typo falls back to a real number (3). This cap is an optional
  // spend valve, so a typo must switch it OFF rather than invent a limit
  // nobody configured and lock out every user of the service.
  for (const value of ["abc", null, -5, 0, 0.5, {}, [], true]) {
    assertEquals(
      parseRuntimeConfig([{ key: "global_daily_call_cap", value }], env())
        .globalDailyCallCap,
      null,
      `${JSON.stringify(value)} should mean unlimited`,
    );
  }

  // Same input shape, opposite direction, in one place so the contrast cannot
  // be edited away by accident.
  assertEquals(
    parseRuntimeConfig([{ key: "daily_limit", value: 0 }], env()).dailyLimit,
    3,
  );
});

Deno.test("a cap of 1 is honoured, not rounded away as falsy", () => {
  // The tightest real setting an operator might use in an incident.
  assertEquals(
    parseRuntimeConfig([{ key: "global_daily_call_cap", value: 1 }], env())
      .globalDailyCallCap,
    1,
  );
});

// ── azureOcrEnabled — dark-launched (F13-T03) ────────────────────────────

Deno.test("azureOcrEnabled is off until an operator explicitly turns it on", () => {
  assertEquals(parseRuntimeConfig(SEEDED, env()).azureOcrEnabled, false);
  assertEquals(parseRuntimeConfig([], env()).azureOcrEnabled, false);
  assertEquals(DEFAULT_RUNTIME_CONFIG.azureOcrEnabled, false);
});

Deno.test("an operator can turn azureOcrEnabled on without an app release", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "azure_ocr_enabled", value: true }], env())
      .azureOcrEnabled,
    true,
  );
  assertEquals(
    parseRuntimeConfig([{ key: "azure_ocr_enabled", value: "true" }], env())
      .azureOcrEnabled,
    true,
  );
});

Deno.test("azureOcrEnabled tolerates hand-edited 'on' spellings", () => {
  for (const value of ["true", "TRUE", " on ", "yes", "1", 1, true]) {
    assertEquals(
      parseRuntimeConfig([{ key: "azure_ocr_enabled", value }], env())
        .azureOcrEnabled,
      true,
      `${JSON.stringify(value)} should enable`,
    );
  }
});

Deno.test("anything short of an explicit 'on' leaves azureOcrEnabled off — the opposite of the kill switch", () => {
  // analysisEnabled fails toward "stopped" because its only reason to be
  // touched is halting a live service. This flag is the mirror image: nothing
  // has been approved as safe to call yet, so even the documented "off"
  // spellings and outright garbage all land on the same disabled default.
  for (
    const value of ["false", "FALSE", "off", "no", "0", 0, false, { nonsense: true }, [], "maybe"]
  ) {
    assertEquals(
      parseRuntimeConfig([{ key: "azure_ocr_enabled", value }], env())
        .azureOcrEnabled,
      false,
      `${JSON.stringify(value)} should stay off`,
    );
  }
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
