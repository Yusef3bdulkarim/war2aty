/**
 * F06-T07 · Tests for the reservation lifecycle.
 *
 * These use a fake store: the atomicity is SQL's job and is proven in
 * `slot-reservation.integration.test.ts`. What matters here is that no path
 * through `withReservedSlot` can leak or wrongly consume a slot.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  type FinalizeResult,
  type ReservationResult,
  type ReserveInput,
  type SlotStore,
  withReservedSlot,
} from "../../functions/_shared/usage/slot-reservation.ts";

const INPUT: ReserveInput = {
  userId: "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  day: "2026-07-26",
  requestId: "aaaaaaaa-0000-0000-0000-000000000001",
  installationHash: "hash",
  dailyLimit: 3,
  ttlSeconds: 60,
};

interface FinalizeCall {
  requestId: string;
  success: boolean;
  errorCode?: string;
}

function fakeStore(outcome: ReservationResult["outcome"] = "reserved") {
  const finalizeCalls: FinalizeCall[] = [];
  let reserveCount = 0;

  const store: SlotStore = {
    reserve(): Promise<ReservationResult> {
      reserveCount += 1;
      return Promise.resolve({ outcome, usedToday: 0, reservedToday: 1 });
    },
    finalize(requestId, success, errorCode): Promise<FinalizeResult> {
      finalizeCalls.push({ requestId, success, errorCode });
      return Promise.resolve({
        outcome: success ? "succeeded" : "released",
        usedToday: success ? 1 : 0,
        reservedToday: 0,
      });
    },
  };

  return {
    store,
    finalizeCalls,
    get reserveCount() {
      return reserveCount;
    },
  };
}

Deno.test("a successful run consumes the slot", async () => {
  const { store, finalizeCalls } = fakeStore();

  const result = await withReservedSlot(store, INPUT, () => Promise.resolve("analysis"));

  assertEquals(result.status, "ran");
  assert(result.status === "ran");
  assertEquals(result.value, "analysis");
  assertEquals(finalizeCalls.length, 1);
  assertEquals(finalizeCalls[0].success, true);
  assertEquals(finalizeCalls[0].requestId, INPUT.requestId);
});

Deno.test("a thrown error releases the slot and rethrows", async () => {
  const { store, finalizeCalls } = fakeStore();

  await assertRejects(
    () =>
      withReservedSlot(store, INPUT, () => {
        throw ApiError.timeout();
      }),
    ApiError,
  );

  // Released, not consumed: a failed analysis must cost the user nothing.
  assertEquals(finalizeCalls.length, 1);
  assertEquals(finalizeCalls[0].success, false);
});

Deno.test("the release records the error code for diagnostics", async () => {
  const { store, finalizeCalls } = fakeStore();

  await assertRejects(() =>
    withReservedSlot(store, INPUT, () => Promise.reject(ApiError.aiRateLimited()))
  );

  assertEquals(finalizeCalls[0].errorCode, "AI_RATE_LIMITED");
});

Deno.test("an unexpected throw still releases, under a generic code", async () => {
  const { store, finalizeCalls } = fakeStore();

  await assertRejects(() =>
    withReservedSlot(store, INPUT, () => {
      throw new TypeError("undefined is not a function");
    })
  );

  assertEquals(finalizeCalls[0].success, false);
  // Never the raw message — it can quote the payload that broke.
  assertEquals(finalizeCalls[0].errorCode, "INTERNAL_ERROR");
});

Deno.test("an unsupported document runs but is not counted", async () => {
  // §31 rule 6: `status: "unsupported"` is a 200, and must not use up quota.
  const { store, finalizeCalls } = fakeStore();

  const result = await withReservedSlot(
    store,
    INPUT,
    () => Promise.resolve({ status: "unsupported" }),
    (value) => value.status !== "unsupported",
  );

  assertEquals(result.status, "ran");
  assertEquals(finalizeCalls[0].success, false);
});

Deno.test("a supported document under the same predicate IS counted", async () => {
  const { store, finalizeCalls } = fakeStore();

  await withReservedSlot(
    store,
    INPUT,
    () => Promise.resolve({ status: "success" }),
    (value) => value.status !== "unsupported",
  );

  assertEquals(finalizeCalls[0].success, true);
});

Deno.test("a refused reservation never runs the work", async () => {
  const { store, finalizeCalls } = fakeStore("limit_reached");
  let ran = false;

  const result = await withReservedSlot(store, INPUT, () => {
    ran = true;
    return Promise.resolve("analysis");
  });

  assertEquals(result.status, "limit_reached");
  // Critical: the AI must not be called, or the limit costs us money anyway.
  assertEquals(ran, false);
  assertEquals(finalizeCalls.length, 0);
});

Deno.test("a duplicate never runs the work and takes no slot", async () => {
  const { store, finalizeCalls } = fakeStore("duplicate");
  let ran = false;

  const result = await withReservedSlot(store, INPUT, () => {
    ran = true;
    return Promise.resolve("analysis");
  });

  assertEquals(result.status, "duplicate");
  assertEquals(ran, false);
  assertEquals(finalizeCalls.length, 0);
});

Deno.test("the slot is reserved exactly once per call", async () => {
  const fake = fakeStore();

  await withReservedSlot(fake.store, INPUT, () => Promise.resolve(1));

  assertEquals(fake.reserveCount, 1);
});
