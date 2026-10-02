/**
 * F20-T11 · Tests for the analysis chain's timing, read from the environment.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { chainTimingFromEnv } from "../../functions/_shared/ai/chain-timing.ts";
import {
  DEFAULT_ATTEMPT_CAP_MS,
  DEFAULT_MIN_FALLBACK_MS,
} from "../../functions/_shared/ai/fallback-provider.ts";

function env(values: Record<string, string>) {
  return (name: string) => values[name];
}

Deno.test("unset variables fall back to the T09 values", () => {
  assertEquals(chainTimingFromEnv(env({})), {
    attemptCapMs: DEFAULT_ATTEMPT_CAP_MS,
    minFallbackMs: DEFAULT_MIN_FALLBACK_MS,
  });
});

Deno.test("blank variables count as unset", () => {
  const timing = chainTimingFromEnv(env({ AI_ATTEMPT_TIMEOUT_SECONDS: "  ", MIN_FALLBACK_MS: "" }));

  assertEquals(timing.attemptCapMs, DEFAULT_ATTEMPT_CAP_MS);
  assertEquals(timing.minFallbackMs, DEFAULT_MIN_FALLBACK_MS);
});

Deno.test("the attempt timeout is read in seconds and handed on in milliseconds", () => {
  const timing = chainTimingFromEnv(env({ AI_ATTEMPT_TIMEOUT_SECONDS: " 12.5 " }));

  assertEquals(timing.attemptCapMs, 12_500);
});

Deno.test("the fallback floor is read in milliseconds", () => {
  const timing = chainTimingFromEnv(env({ MIN_FALLBACK_MS: "4000" }));

  assertEquals(timing.minFallbackMs, 4_000);
});

for (const bad of ["0", "-3", "abc", "Infinity", "NaN"]) {
  Deno.test(`an attempt timeout of "${bad}" is a deploy fault`, () => {
    assertThrows(
      () => chainTimingFromEnv(env({ AI_ATTEMPT_TIMEOUT_SECONDS: bad })),
      Error,
      "AI_ATTEMPT_TIMEOUT_SECONDS must be a positive number.",
    );
  });
}

Deno.test("a fallback floor that is not a positive number is a deploy fault", () => {
  assertThrows(
    () => chainTimingFromEnv(env({ MIN_FALLBACK_MS: "-1" })),
    Error,
    "MIN_FALLBACK_MS must be a positive number.",
  );
});

Deno.test("the error names the variable, never its value", () => {
  const error = assertThrows(() => chainTimingFromEnv(env({ MIN_FALLBACK_MS: "secret-ish" })));

  assertEquals((error as Error).message.includes("secret-ish"), false);
});
