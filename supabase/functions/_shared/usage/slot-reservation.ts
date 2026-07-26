/**
 * F06-T07 · Slot reservation, seen from TypeScript.
 *
 * The atomicity lives in SQL (`reserve_analysis_slot`); this module is the
 * typed seam over it plus {@link withReservedSlot}, which makes the lifecycle
 * structural rather than something each endpoint has to remember.
 *
 * Why a reservation at all: the AI call takes seconds. Counting only on
 * success would let a user fire many requests in that window; counting on
 * arrival would charge them for analyses that failed. Reserving up front and
 * settling afterwards is the only shape that is both fair and safe.
 */

import { toApiError } from "../errors/api-error.ts";
import type { CairoDay } from "../time/cairo-day.ts";

/**
 * - `reserved` — a slot is held; the caller must finalize it.
 * - `duplicate` — this `request_id` was already seen. A retry, not a new
 *   analysis, so no slot was taken.
 * - `limit_reached` — the daily quota is exhausted.
 */
export type ReserveOutcome = "reserved" | "duplicate" | "limit_reached";

export interface ReservationResult {
  readonly outcome: ReserveOutcome;
  readonly usedToday: number;
  readonly reservedToday: number;
}

/**
 * - `succeeded` — counted against the quota.
 * - `released` — the slot was handed back; the analysis cost nothing.
 * - `not_reserved` — nothing was open under that id (already finalized, or
 *   swept as expired). Not an error: finalize is idempotent by design.
 */
export type FinalizeOutcome = "succeeded" | "released" | "not_reserved";

export interface FinalizeResult {
  readonly outcome: FinalizeOutcome;
  readonly usedToday: number;
  readonly reservedToday: number;
}

export interface ReserveInput {
  readonly userId: string;
  readonly day: CairoDay;
  readonly requestId: string;
  /** Salted hash — never the raw installation id. */
  readonly installationHash: string;
  readonly dailyLimit: number;
  /**
   * How long the slot may stay held. Should exceed the AI timeout but stay
   * short: until it lapses, a crashed request keeps a slot from the user.
   */
  readonly ttlSeconds: number;
}

export interface SlotStore {
  reserve(input: ReserveInput): Promise<ReservationResult>;
  finalize(
    requestId: string,
    success: boolean,
    errorCode?: string,
  ): Promise<FinalizeResult>;
}

export type SlotRunOutcome<T> =
  | { readonly status: "ran"; readonly value: T; readonly finalize: FinalizeResult }
  | { readonly status: "duplicate" | "limit_reached"; readonly reservation: ReservationResult };

/**
 * Runs `work` while holding a slot, settling it whichever way `work` ends.
 *
 * The point is that no path can leak a reservation: a throw releases the slot
 * and rethrows, so a crash mid-analysis costs the user nothing. Doing this by
 * hand in each endpoint is exactly the kind of thing that gets forgotten in
 * the error branch.
 *
 * @param countsAsSuccess Decides whether a completed run consumes the quota.
 * An `unsupported` document is a normal 200 but must NOT be counted (§31
 * rule 6), so the caller — not this function — owns that judgement.
 */
export async function withReservedSlot<T>(
  store: SlotStore,
  input: ReserveInput,
  work: () => Promise<T>,
  countsAsSuccess: (value: T) => boolean = () => true,
): Promise<SlotRunOutcome<T>> {
  const reservation = await store.reserve(input);

  if (reservation.outcome !== "reserved") {
    return { status: reservation.outcome, reservation };
  }

  let value: T;
  try {
    value = await work();
  } catch (thrown) {
    // Release before rethrowing: the analysis never produced a result, so it
    // must not cost the user a slot. The code is recorded for diagnostics; it
    // is a §31 enum value and carries no document content.
    await store.finalize(input.requestId, false, toApiError(thrown).code);
    throw thrown;
  }

  const finalize = await store.finalize(
    input.requestId,
    countsAsSuccess(value),
  );

  return { status: "ran", value, finalize };
}
