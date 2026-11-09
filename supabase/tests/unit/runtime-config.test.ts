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

// ── onlineOcrEnabled — opt-in (F13-T03, renamed in F20-T14) ────────────────────────────

Deno.test("onlineOcrEnabled is off until an operator explicitly turns it on", () => {
  assertEquals(parseRuntimeConfig(SEEDED, env()).onlineOcrEnabled, false);
  assertEquals(parseRuntimeConfig([], env()).onlineOcrEnabled, false);
  assertEquals(DEFAULT_RUNTIME_CONFIG.onlineOcrEnabled, false);
});

Deno.test("an operator can turn onlineOcrEnabled on without an app release", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "online_ocr_enabled", value: true }], env())
      .onlineOcrEnabled,
    true,
  );
  assertEquals(
    parseRuntimeConfig([{ key: "online_ocr_enabled", value: "true" }], env())
      .onlineOcrEnabled,
    true,
  );
});

Deno.test("onlineOcrEnabled tolerates hand-edited 'on' spellings", () => {
  for (const value of ["true", "TRUE", " on ", "yes", "1", 1, true]) {
    assertEquals(
      parseRuntimeConfig([{ key: "online_ocr_enabled", value }], env())
        .onlineOcrEnabled,
      true,
      `${JSON.stringify(value)} should enable`,
    );
  }
});

Deno.test("anything short of an explicit 'on' leaves onlineOcrEnabled off — the opposite of the kill switch", () => {
  // analysisEnabled fails toward "stopped" because its only reason to be
  // touched is halting a live service. This flag is the mirror image: nothing
  // has been approved as safe to call yet, so even the documented "off"
  // spellings and outright garbage all land on the same disabled default.
  for (
    const value of ["false", "FALSE", "off", "no", "0", 0, false, { nonsense: true }, [], "maybe"]
  ) {
    assertEquals(
      parseRuntimeConfig([{ key: "online_ocr_enabled", value }], env())
        .onlineOcrEnabled,
      false,
      `${JSON.stringify(value)} should stay off`,
    );
  }
});

Deno.test("a leftover azure_ocr_enabled row never turns online reading on (F20-T14)", () => {
  // The F13 key switched on Azure. Honouring it would switch on a different
  // provider, Gemini, that nobody approved by setting it.
  const config = parseRuntimeConfig([{ key: "azure_ocr_enabled", value: true }], env());

  assertEquals(config.onlineOcrEnabled, false);
});

// ── explainSchemaVersion — independent of schemaVersion (F35-T04) ─────────

Deno.test("explainSchemaVersion starts at 1.0, not at the analysis contract's version", () => {
  assertEquals(parseRuntimeConfig(SEEDED, env()).explainSchemaVersion, "1.0");
  assertEquals(parseRuntimeConfig([], env()).explainSchemaVersion, "1.0");
  assertEquals(DEFAULT_RUNTIME_CONFIG.explainSchemaVersion, "1.0");
});

Deno.test("the seeded explain_schema_version row is read", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "explain_schema_version", value: "1.0" }], env())
      .explainSchemaVersion,
    "1.0",
  );
});

Deno.test("a blank or malformed explain_schema_version falls back rather than emptying the contract", () => {
  for (const value of ["", "   ", null, 2, { v: "1.0" }, []]) {
    assertEquals(
      parseRuntimeConfig([{ key: "explain_schema_version", value }], env())
        .explainSchemaVersion,
      "1.0",
      `${JSON.stringify(value)} should fall back`,
    );
  }
});

Deno.test("the two schema versions move independently — the published app cannot be broken by bumping the new one", () => {
  // The whole reason `explain_schema_version` exists. `analyze-request.ts`
  // compares the client's `schema_version` with `!==` and answers 400
  // UNSUPPORTED_SCHEMA on a mismatch, so if F34's endpoint had been versioned
  // on that row, the first bump would have refused every published build.
  const explainBumped = parseRuntimeConfig(
    [...SEEDED, { key: "explain_schema_version", value: "1.1" }],
    env(),
  );

  assertEquals(explainBumped.explainSchemaVersion, "1.1");
  assertEquals(explainBumped.schemaVersion, "2.0", "the published contract must not move");

  // And the converse: the analysis contract moving must not drag the new one
  // along, or an old-client fix would silently change the new endpoint.
  const analysisBumped = parseRuntimeConfig(
    [{ key: "schema_version", value: "3.0" }],
    env(),
  );

  assertEquals(analysisBumped.schemaVersion, "3.0");
  assertEquals(analysisBumped.explainSchemaVersion, "1.0");
});

// ── explainEnabled — opt-in (F35-T04) ─────────────────────────────────────

Deno.test("explainEnabled is off until an operator explicitly turns it on", () => {
  assertEquals(parseRuntimeConfig(SEEDED, env()).explainEnabled, false);
  assertEquals(parseRuntimeConfig([], env()).explainEnabled, false);
  assertEquals(DEFAULT_RUNTIME_CONFIG.explainEnabled, false);
});

Deno.test("an operator can turn explainEnabled on without an app release", () => {
  for (const value of ["true", "TRUE", " on ", "yes", "1", 1, true]) {
    assertEquals(
      parseRuntimeConfig([{ key: "explain_enabled", value }], env()).explainEnabled,
      true,
      `${JSON.stringify(value)} should enable`,
    );
  }
});

Deno.test("anything short of an explicit 'on' leaves explainEnabled off", () => {
  // Same mirror-of-the-kill-switch reasoning as `online_ocr_enabled`: an
  // unverified provider chain must not become callable because a deploy
  // happened, so even the documented "off" spellings land on disabled.
  for (
    const value of ["false", "FALSE", "off", "no", "0", 0, false, { nonsense: true }, [], "maybe"]
  ) {
    assertEquals(
      parseRuntimeConfig([{ key: "explain_enabled", value }], env()).explainEnabled,
      false,
      `${JSON.stringify(value)} should stay off`,
    );
  }
});

Deno.test("the two feature gates are independent of each other", () => {
  // `online_ocr_enabled` is ON in production (20261010120000). If that row
  // leaked into this flag, F36's unverified chain would be live the moment it
  // deployed.
  const config = parseRuntimeConfig([{ key: "online_ocr_enabled", value: true }], env());

  assertEquals(config.onlineOcrEnabled, true);
  assertEquals(config.explainEnabled, false);
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

// ── retired keys ──────────────────────────────────────────────────────────

Deno.test("a leftover gemini_primary_enabled row is ignored", () => {
  // F18's provider-order flag was removed in F20-T04. A database where an
  // operator once set the row must still parse, and must not grow a field
  // that nothing reads.
  const config = parseRuntimeConfig(
    [{ key: "gemini_primary_enabled", value: true }],
    env(),
  );

  assertEquals("geminiPrimaryEnabled" in config, false);
  assertEquals(config, parseRuntimeConfig([], env()));
});

// ── explainDailyLimit — a second quota row, not a louder one (F36-T04) ────

Deno.test("explainDailyLimit is 5 while dailyLimit stays 3", () => {
  const config = parseRuntimeConfig(SEEDED, env());

  assertEquals(config.explainDailyLimit, 5);
  assertEquals(config.dailyLimit, 3);
  assertEquals(DEFAULT_RUNTIME_CONFIG.explainDailyLimit, 5);
});

Deno.test("the seeded explain_daily_limit row is read", () => {
  assertEquals(
    parseRuntimeConfig(
      [...SEEDED, { key: "explain_daily_limit", value: 5 }],
      env(),
    ).explainDailyLimit,
    5,
  );
});

Deno.test("an operator can move the explain limit without an app release", () => {
  assertEquals(
    parseRuntimeConfig([{ key: "explain_daily_limit", value: 8 }], env())
      .explainDailyLimit,
    8,
  );
  assertEquals(
    parseRuntimeConfig([{ key: "explain_daily_limit", value: "7" }], env())
      .explainDailyLimit,
    7,
  );
  assertEquals(
    parseRuntimeConfig([{ key: "explain_daily_limit", value: 4.9 }], env())
      .explainDailyLimit,
    4,
  );
});

Deno.test("a malformed explain limit falls back to 5 rather than to zero", () => {
  // Same fail direction as `daily_limit`, and the opposite of
  // `global_daily_call_cap`: a mandatory product decision falls back to a real
  // number, because the alternatives are locking everyone out (0) or handing
  // out unlimited analyses (null).
  for (const value of ["abc", null, -5, 0, {}, [], true]) {
    assertEquals(
      parseRuntimeConfig([{ key: "explain_daily_limit", value }], env())
        .explainDailyLimit,
      5,
      `${JSON.stringify(value)} should fall back`,
    );
  }
});

Deno.test("an absent explain_daily_limit row reads as 5, not as unlimited", () => {
  assertEquals(parseRuntimeConfig([], env()).explainDailyLimit, 5);
});

Deno.test("the two quota rows move independently", () => {
  // The whole reason this key exists: the published 1.0.2 app reads
  // `daily_limit` for `analyze-document` and draws it on Home. Raising one
  // must never raise the other.
  const explainRaised = parseRuntimeConfig(
    [...SEEDED, { key: "explain_daily_limit", value: 10 }],
    env(),
  );
  assertEquals(explainRaised.explainDailyLimit, 10);
  assertEquals(explainRaised.dailyLimit, 3);

  const analysisRaised = parseRuntimeConfig(
    [{ key: "daily_limit", value: 9 }],
    env(),
  );
  assertEquals(analysisRaised.dailyLimit, 9);
  assertEquals(analysisRaised.explainDailyLimit, 5);
});
