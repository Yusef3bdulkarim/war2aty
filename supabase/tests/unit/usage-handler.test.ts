/**
 * F06-T13 · Tests for the get-usage endpoint.
 *
 * This endpoint decides what the Home screen tells the user before they
 * photograph anything, so the numbers must be honest in both directions: never
 * promising an analysis the quota will refuse, never hiding one they still have.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
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
    schema_version: "1.0",
    usage_date: "2026-07-26",
    daily_limit: 3,
    used_today: 0,
    remaining_today: 3,
    resets_at: "2026-07-27T00:00:00+03:00",
    analysis_enabled: true,
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
