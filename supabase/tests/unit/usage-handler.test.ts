/**
 * F06-T13 · Tests for the get-usage endpoint.
 *
 * This endpoint decides what the Home screen tells the user before they
 * photograph anything, so the numbers must be honest in both directions: never
 * promising an analysis the quota will refuse, never hiding one they still have.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import {
  parseRuntimeConfig,
  type RuntimeConfig,
} from "../../functions/_shared/config/runtime-config.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import type { DailyUsage } from "../../functions/_shared/usage/usage-service.ts";
import { createUsageHandler } from "../../functions/_shared/usage/usage-handler.ts";
import { NOW, testConfig, USER_ID } from "../fixtures/analyze-fixtures.ts";

const VALID_TOKEN = "valid-token";

interface HarnessOptions {
  readonly config?: Partial<RuntimeConfig>;
  readonly usage?: DailyUsage;
}

function harness(options: HarnessOptions = {}) {
  const readCalls: { userId: string; day: string }[] = [];

  const handler = createEndpoint({
    name: "get-usage",
    method: "GET",
    handle: createUsageHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: () => Promise.resolve(testConfig(options.config)),
      readUsage: (userId, day) => {
        readCalls.push({ userId, day });
        return Promise.resolve(
          options.usage ?? { successfulCount: 0, reservedCount: 0 },
        );
      },
      now: () => NOW,
    }),
  });

  return {
    readCalls,
    call: (headers: Record<string, string> = {}) =>
      handler(
        new Request("https://example.test/functions/v1/get-usage", {
          method: "GET",
          headers: { Authorization: `Bearer ${VALID_TOKEN}`, ...headers },
        }),
      ),
  };
}

Deno.test("a fresh day reports the full allowance", async () => {
  const response = await harness().call();

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    schema_version: "2.0",
    usage_date: "2026-07-26",
    daily_limit: 3,
    used_today: 0,
    remaining_today: 3,
    resets_at: "2026-07-27T00:00:00+03:00",
    analysis_enabled: true,
    online_ocr_enabled: false,
    explain_enabled: false,
  });
});

Deno.test("the counters are read for the caller's own Cairo day", async () => {
  const test = harness();
  await test.call();

  // The id comes from the verified token — a caller must not be able to read
  // someone else's quota by asking for it.
  assertEquals(test.readCalls, [{ userId: USER_ID, day: "2026-07-26" }]);
});

Deno.test("in-flight reservations lower what may be started now", async () => {
  // The honest answer to "can I go?": a reserved slot is not yet used, but it
  // is not available either.
  const response = await harness({
    usage: { successfulCount: 1, reservedCount: 1 },
  }).call();

  const body = await response.json();
  assertEquals(body.used_today, 1);
  assertEquals(body.remaining_today, 1);
});

Deno.test("an exhausted quota reports zero remaining, not a negative", async () => {
  const response = await harness({
    usage: { successfulCount: 5, reservedCount: 0 },
    config: { dailyLimit: 3 },
  }).call();

  const body = await response.json();
  assertEquals(body.used_today, 5);
  assertEquals(body.remaining_today, 0);
});

Deno.test("the kill switch is reported so the app can explain before it tries", async () => {
  const response = await harness({ config: { analysisEnabled: false } }).call();
  assertEquals((await response.json()).analysis_enabled, false);
});

Deno.test("the online-pipeline flag is reported so the client can gate routing on it", async () => {
  const off = await harness({ config: { onlineOcrEnabled: false } }).call();
  assertEquals((await off.json()).online_ocr_enabled, false);

  const on = await harness({ config: { onlineOcrEnabled: true } }).call();
  assertEquals((await on.json()).online_ocr_enabled, true);
});

Deno.test("the retired azure_ocr_enabled field is gone from the wire (F20-T14)", async () => {
  // An app built before F20-T17 reads the missing field as false and stays
  // on the on-device route: the safe direction for a stale client.
  const body = await (await harness({ config: { onlineOcrEnabled: true } }).call()).json();

  assertEquals("azure_ocr_enabled" in body, false);
});

Deno.test("a runtime limit change is reflected immediately", async () => {
  const response = await harness({ config: { dailyLimit: 10 } }).call();

  const body = await response.json();
  assertEquals(body.daily_limit, 10);
  assertEquals(body.remaining_today, 10);
});

Deno.test("an unauthenticated caller is refused and no counters are read", async () => {
  const test = harness();
  const response = await test.call({ Authorization: "" });

  assertEquals(response.status, 401);
  assertEquals((await response.json()).error.code, "UNAUTHORIZED");
  assertEquals(test.readCalls.length, 0);
});

Deno.test("resets_at carries Cairo's real offset, never a hard-coded +02:00", async () => {
  // Egypt observes DST again since 2023; a fixed offset would hand users a free
  // analysis — or deny them one — around midnight for half the year (§27).
  const response = await harness().call();
  const body = await response.json();

  assert(
    body.resets_at.endsWith("+03:00"),
    `July is EEST in Cairo, got ${body.resets_at}`,
  );
});

// ── explain_enabled — F34's capture gate on the wire (F36-T05) ─────────────

Deno.test("the explain gate is reported so the app can refuse honestly", async () => {
  const off = await harness({ config: { explainEnabled: false } }).call();
  assertEquals((await off.json()).explain_enabled, false);

  const on = await harness({ config: { explainEnabled: true } }).call();
  assertEquals((await on.json()).explain_enabled, true);
});

Deno.test("explain_enabled is false unless an operator turned it on", async () => {
  // The default, and the direction that matters: a chain nobody has verified
  // must never be advertised as available because a deploy happened.
  const body = await (await harness().call()).json();
  assertEquals(body.explain_enabled, false);
});

Deno.test("an absent, unreadable or 'off' row reaches the wire as false", async () => {
  // The flag is `optInFlag` all the way down, so this test drives the REAL
  // parser rather than a handcrafted config: the handler can only be as
  // trustworthy as what `parseRuntimeConfig` hands it.
  for (
    const rows of [
      [],
      [{ key: "explain_enabled", value: "off" }],
      [{ key: "explain_enabled", value: "nonsense" }],
      [{ key: "explain_enabled", value: 0 }],
      [{ key: "explain_enabled", value: null }],
    ]
  ) {
    const config = parseRuntimeConfig(rows, { get: () => undefined });
    const body = await (await harness({ config }).call()).json();
    assertEquals(
      body.explain_enabled,
      false,
      `${JSON.stringify(rows)} should reach the wire as false`,
    );
  }

  const enabled = parseRuntimeConfig(
    [{ key: "explain_enabled", value: true }],
    { get: () => undefined },
  );
  assertEquals((await (await harness({ config: enabled }).call()).json()).explain_enabled, true);
});

Deno.test("the other eight fields are untouched by the new one", async () => {
  // The published 1.0.2 app reads this body. Adding a field must add a field
  // and nothing else — no rename, no reorder of meaning, no dropped key.
  const body = await (await harness({ config: { explainEnabled: true } }).call()).json();

  assertEquals(Object.keys(body).sort(), [
    "analysis_enabled",
    "daily_limit",
    "explain_enabled",
    "online_ocr_enabled",
    "remaining_today",
    "resets_at",
    "schema_version",
    "usage_date",
    "used_today",
  ]);
  assertEquals(body.schema_version, "2.0");
  assertEquals(body.usage_date, "2026-07-26");
  assertEquals(body.daily_limit, 3);
  assertEquals(body.used_today, 0);
  assertEquals(body.remaining_today, 3);
  assertEquals(body.resets_at, "2026-07-27T00:00:00+03:00");
  assertEquals(body.analysis_enabled, true);
  assertEquals(body.online_ocr_enabled, false);
});

Deno.test("get-usage still reports daily_limit, not explain_daily_limit", async () => {
  // Two quota rows now exist (F36-T04). This endpoint serves the PUBLISHED
  // app's counter, so it must keep reporting the old one; F39 reads the new
  // limit through the explain flow, never from here.
  const body = await (await harness({
    config: { dailyLimit: 3, explainDailyLimit: 5 },
  }).call()).json();

  assertEquals(body.daily_limit, 3);
  assertEquals("explain_daily_limit" in body, false);
});
