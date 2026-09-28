/**
 * F20-T03 · Tests for the single request deadline (timeout contract §2).
 *
 * Driven entirely by an injected clock and signal factory, so nothing here
 * waits on a real timer.
 */

import {
  assert,
  assertEquals,
  assertInstanceOf,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1";

import { createDeadline } from "../../functions/_shared/time/deadline.ts";

/** A clock the test moves by hand. */
function fakeClock(start = 1_000_000) {
  let current = start;
  return {
    now: () => current,
    advance: (ms: number) => {
      current += ms;
    },
  };
}

/** Records every budget handed to the timer, returning a never-firing signal. */
function recordingSignals() {
  const budgets: number[] = [];
  return {
    budgets,
    timeoutSignal: (ms: number) => {
      budgets.push(ms);
      return new AbortController().signal;
    },
  };
}

// ── remaining time ────────────────────────────────────────────────────────

Deno.test("remainingMs starts at the full budget", () => {
  const clock = fakeClock();
  const deadline = createDeadline(25_000, { now: clock.now });

  assertEquals(deadline.remainingMs(), 25_000);
  assertEquals(deadline.isExpired(), false);
});

Deno.test("remainingMs shrinks with elapsed time and is floored", () => {
  const clock = fakeClock();
  const deadline = createDeadline(25_000, { now: clock.now });

  clock.advance(9_999.6);

  assertEquals(deadline.remainingMs(), 15_000);
});

Deno.test("remainingMs never goes negative and the deadline reports expiry", () => {
  const clock = fakeClock();
  const deadline = createDeadline(1_000, { now: clock.now });

  clock.advance(5_000);

  assertEquals(deadline.remainingMs(), 0);
  assertEquals(deadline.isExpired(), true);
});

Deno.test("the deadline expires exactly at its end, not a millisecond later", () => {
  const clock = fakeClock();
  const deadline = createDeadline(1_000, { now: clock.now });

  clock.advance(999);
  assertEquals(deadline.isExpired(), false);

  clock.advance(1);
  assertEquals(deadline.isExpired(), true);
});

// ── per-attempt budget ────────────────────────────────────────────────────

Deno.test("an uncapped attempt gets everything that remains", () => {
  const clock = fakeClock();
  const deadline = createDeadline(25_000, { now: clock.now });

  clock.advance(200);

  assertEquals(deadline.budgetMs(), 24_800);
});

Deno.test("a capped attempt gets the cap while plenty remains", () => {
  const clock = fakeClock();
  const deadline = createDeadline(25_000, { now: clock.now });

  assertEquals(deadline.budgetMs(15_000), 15_000);
});

Deno.test("a capped attempt gets only what remains once that is below the cap", () => {
  // The fallback after a primary that burned its whole capped attempt.
  const clock = fakeClock();
  const deadline = createDeadline(25_000, { now: clock.now });

  clock.advance(15_000);

  assertEquals(deadline.budgetMs(15_000), 10_000);
});

Deno.test("an expired deadline leaves a zero budget, capped or not", () => {
  const clock = fakeClock();
  const deadline = createDeadline(1_000, { now: clock.now });

  clock.advance(2_000);

  assertEquals(deadline.budgetMs(), 0);
  assertEquals(deadline.budgetMs(500), 0);
});

// ── signals ───────────────────────────────────────────────────────────────

Deno.test("signal arms the timer with exactly the attempt's budget", () => {
  const clock = fakeClock();
  const signals = recordingSignals();
  const deadline = createDeadline(25_000, { now: clock.now, timeoutSignal: signals.timeoutSignal });

  deadline.signal(15_000);
  clock.advance(15_000);
  deadline.signal(15_000);

  assertEquals(signals.budgets, [15_000, 10_000]);
});

Deno.test("once expired, signal is already aborted with a TimeoutError", () => {
  const clock = fakeClock();
  const signals = recordingSignals();
  const deadline = createDeadline(1_000, { now: clock.now, timeoutSignal: signals.timeoutSignal });

  clock.advance(1_000);
  const signal = deadline.signal();

  assert(signal.aborted);
  assertInstanceOf(signal.reason, DOMException);
  assertEquals((signal.reason as DOMException).name, "TimeoutError");
  // No zero-length timer is ever armed.
  assertEquals(signals.budgets, []);
});

Deno.test("fetch given an expired deadline's signal rejects as a timeout", async () => {
  // The contract transports rely on: one `TimeoutError` check covers both a
  // timer firing mid-request and a deadline that was already spent.
  const clock = fakeClock();
  const deadline = createDeadline(1_000, { now: clock.now });
  clock.advance(1_000);

  const error = await assertRejects(
    () => fetch("http://127.0.0.1:9/", { signal: deadline.signal() }),
    DOMException,
  );

  assertEquals(error.name, "TimeoutError");
});

// ── programmer errors ─────────────────────────────────────────────────────

for (const bad of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
  Deno.test(`a total of ${bad} is rejected`, () => {
    assertThrows(() => createDeadline(bad), RangeError);
  });

  Deno.test(`a cap of ${bad} is rejected`, () => {
    const deadline = createDeadline(1_000);

    assertThrows(() => deadline.budgetMs(bad), RangeError);
    assertThrows(() => deadline.signal(bad), RangeError);
  });
}
