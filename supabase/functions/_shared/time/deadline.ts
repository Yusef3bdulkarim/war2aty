/**
 * F20-T03 · `Deadline` — one time budget for a whole request.
 *
 * F18 split the analysis budget up front: 60% for the primary provider and the
 * rest for the fallback. F20 replaces that with a single deadline for the whole
 * request (timeout contract §2). Every provider attempt gets only what is
 * *actually* left when it starts, optionally bounded by a per-attempt cap:
 * - A primary that fails in 200ms leaves the fallback nearly the whole budget.
 * - A primary that hangs is cut off by the cap, not by the full budget, so the
 *   fallback still has time to run.
 * - No combination of attempts can outlive the budget, so the slot-TTL
 *   arithmetic in `analyze-handler.ts` stays true.
 *
 * Time is measured from an injected clock, so every budget decision is
 * testable without timers or a network.
 */

export interface Deadline {
  /** Milliseconds left, floored, never negative. */
  remainingMs(): number;
  isExpired(): boolean;
  /**
   * The budget for one attempt started now: what remains, bounded by `capMs`
   * when given. Zero once expired.
   */
  budgetMs(capMs?: number): number;
  /**
   * An `AbortSignal` that fires when this attempt's {@link budgetMs} runs out.
   *
   * Once the deadline has expired the signal is already aborted, with a
   * `TimeoutError` `DOMException` as its reason. A `fetch` given that signal
   * rejects exactly as it would on a real timeout, so transports need only one
   * code path for "out of time".
   */
  signal(capMs?: number): AbortSignal;
}

export interface DeadlineOptions {
  /** Milliseconds since epoch. Injected so tests need no real clock. */
  readonly now?: () => number;
  /** Injected so tests can see the budget handed to the timer. */
  readonly timeoutSignal?: (ms: number) => AbortSignal;
}

function assertPositiveFinite(value: number, name: string): void {
  if (!Number.isFinite(value) || value <= 0) {
    // A programmer error, not a runtime condition: the values come from
    // parsed config and constants, never from the request.
    throw new RangeError(`${name} must be a positive, finite number of milliseconds.`);
  }
}

/** Starts a deadline `totalMs` from now. */
export function createDeadline(totalMs: number, options: DeadlineOptions = {}): Deadline {
  assertPositiveFinite(totalMs, "totalMs");

  const { now = Date.now, timeoutSignal = (ms: number) => AbortSignal.timeout(ms) } = options;
  const expiresAt = now() + totalMs;

  const remainingMs = (): number => Math.max(0, Math.floor(expiresAt - now()));

  const budgetMs = (capMs?: number): number => {
    if (capMs !== undefined) assertPositiveFinite(capMs, "capMs");
    const remaining = remainingMs();
    return capMs === undefined ? remaining : Math.min(remaining, Math.floor(capMs));
  };

  return {
    remainingMs,
    isExpired: () => remainingMs() === 0,
    budgetMs,
    signal(capMs?: number): AbortSignal {
      const budget = budgetMs(capMs);
      if (budget === 0) {
        return AbortSignal.abort(new DOMException("Deadline exceeded.", "TimeoutError"));
      }
      return timeoutSignal(budget);
    },
  };
}
