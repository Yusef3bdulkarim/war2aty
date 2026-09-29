/**
 * F06-T13 · Tests for the analyze-document endpoint, end to end with fakes.
 *
 * Every dependency is injected, so these run the REAL sequence — auth, config,
 * kill switch, parsing, reservation, validation, response building — without
 * Docker, a network or a Groq bill, and they are deterministic.
 *
 * The questions being asked are the ones that cost money or trust:
 * does an unauthenticated caller ever reach the AI, does a failed analysis ever
 * consume quota, and does anything from the document escape into a response.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { createAnalyzeHandler } from "../../functions/_shared/analyze/analyze-handler.ts";
import type {
  AiAnalysisProvider,
  AnalysisLeg,
} from "../../functions/_shared/ai/analysis-provider.ts";
import { createFallbackAnalysisProvider } from "../../functions/_shared/ai/fallback-provider.ts";
import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";
import type { AnalysisPromptInput } from "../../functions/_shared/prompts/analysis-prompt.ts";
import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import type {
  FinalizeResult,
  ReservationResult,
  ReserveInput,
  ReserveOutcome,
  SlotStore,
} from "../../functions/_shared/usage/slot-reservation.ts";
import type { ModelAnalysis } from "../../functions/_shared/schemas/analysis-output.schema.ts";
import {
  modelAnalysis,
  NOW,
  OCR_TEXT,
  REQUEST_ID,
  SESSION_ID,
  testConfig,
  USER_ID,
  validImageRequestBody,
  validRequestBody,
} from "../fixtures/analyze-fixtures.ts";

const VALID_TOKEN = "valid-token";

interface Harness {
  readonly call: (
    body?: unknown,
    headers?: Record<string, string>,
  ) => Promise<Response>;
  readonly reserves: ReserveInput[];
  readonly finalizes: { requestId: string; success: boolean; errorCode?: string }[];
  readonly prompts: AnalysisPromptInput[];
  readonly analyserTimeouts: number[];
  readonly analyserRequestIds: string[];
}

interface HarnessOptions {
  readonly config?: Partial<RuntimeConfig>;
  readonly reserveOutcome?: ReserveOutcome;
  readonly analyse?: (input: AnalysisPromptInput) => Promise<ModelAnalysis>;
  readonly loadConfig?: () => Promise<RuntimeConfig>;
  /** Replaces the whole analyser factory, e.g. with the real fallback chain. */
  readonly createAnalyser?: (timeoutSeconds: number, requestId: string) => AiAnalysisProvider;
}

function harness(options: HarnessOptions = {}): Harness {
  const reserves: ReserveInput[] = [];
  const finalizes: { requestId: string; success: boolean; errorCode?: string }[] = [];
  const prompts: AnalysisPromptInput[] = [];
  const analyserTimeouts: number[] = [];
  const analyserRequestIds: string[] = [];

  const config = testConfig(options.config);

  const slots: SlotStore = {
    reserve(input: ReserveInput): Promise<ReservationResult> {
      reserves.push(input);
      return Promise.resolve({
        outcome: options.reserveOutcome ?? "reserved",
        usedToday: 0,
        reservedToday: 1,
      });
    },
    finalize(requestId, success, errorCode): Promise<FinalizeResult> {
      finalizes.push({ requestId, success, errorCode });
      return Promise.resolve({
        outcome: success ? "succeeded" : "released",
        usedToday: success ? 1 : 0,
        reservedToday: 0,
      });
    },
  };

  const analyse: AiAnalysisProvider = (input) => {
    prompts.push(input);
    return options.analyse ? options.analyse(input) : Promise.resolve(modelAnalysis());
  };

  const handler = createEndpoint({
    name: "analyze-document",
    method: "POST",
    handle: createAnalyzeHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: options.loadConfig ?? (() => Promise.resolve(config)),
      slots,
      createAnalyser: (timeoutSeconds, analyserRequestId) => {
        analyserTimeouts.push(timeoutSeconds);
        analyserRequestIds.push(analyserRequestId);
        return options.createAnalyser?.(timeoutSeconds, analyserRequestId) ?? analyse;
      },
      hashInstallation: (id) => Promise.resolve(`hashed:${id.slice(0, 4)}`),
      now: () => NOW,
    }),
  });

  return {
    call: (body = validRequestBody(), headers = {}) =>
      handler(
        new Request("https://example.test/functions/v1/analyze-document", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${VALID_TOKEN}`,
            "Content-Type": "application/json",
            "x-request-id": REQUEST_ID,
            ...headers,
          },
          body: typeof body === "string" ? body : JSON.stringify(body),
        }),
      ),
    reserves,
    finalizes,
    prompts,
    analyserTimeouts,
    analyserRequestIds,
  };
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

/** Runs one request and returns the input the store was actually handed. */
async function reserveInput(test: Harness): Promise<ReserveInput> {
  await test.call();
  return test.reserves[0];
}

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("a valid analysis returns the §30 body and consumes one slot", async () => {
  const test = harness();
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.schema_version, "2.0");
  assertEquals(body.session_id, SESSION_ID);
  assertEquals(body.status, "success");
  assertEquals(body.document_type.type, "invoice");

  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, true);
});

Deno.test("the reservation is keyed on the token's user, never the request body", async () => {
  // A caller must not be able to spend someone else's quota by naming them.
  const test = harness();
  await test.call();

  assertEquals(test.reserves[0].userId, USER_ID);
  assertEquals(test.reserves[0].day, "2026-07-26");
  assertEquals(test.reserves[0].requestId, REQUEST_ID);
});

Deno.test("the raw installation id is never handed to the store", async () => {
  const test = harness();
  await test.call();

  const hash = test.reserves[0].installationHash;
  assert(hash.startsWith("hashed:"), "the store must receive a hash");
  assert(!hash.includes("4c455b099bc9"), "the raw id must never be stored");
});

Deno.test("the slot outlives the AI timeout so a slow success is not swept", async () => {
  const test = harness({ config: { aiTimeoutSeconds: 25 } });
  await test.call();

  assertEquals(test.analyserTimeouts, [25]);
  assert(
    test.reserves[0].ttlSeconds > 25,
    "a slot that expires before the AI does would be swept mid-analysis",
  );
});

Deno.test("the prompt receives the document text and the parsed candidates", async () => {
  const test = harness();
  await test.call();

  assertEquals(test.prompts[0].ocrText, OCR_TEXT);
  assertEquals(test.prompts[0].detectedLanguages, ["ar"]);
  assertEquals(test.prompts[0].candidates.dates.length, 1);
});

// ── refusals that must happen before the AI is called ─────────────────────

Deno.test("an unauthenticated caller never reaches the AI", async () => {
  const test = harness();
  const response = await test.call(validRequestBody(), { Authorization: "" });

  assertEquals(response.status, 401);
  assertEquals(await errorCode(response), "UNAUTHORIZED");
  assertEquals(test.prompts.length, 0);
  assertEquals(test.reserves.length, 0);
});

Deno.test("an invalid token is 401 and takes no slot", async () => {
  const test = harness();
  const response = await test.call(validRequestBody(), {
    Authorization: "Bearer forged",
  });

  assertEquals(response.status, 401);
  assertEquals(test.reserves.length, 0);
});

Deno.test("the kill switch stops analysis with 503 before anything is parsed", async () => {
  const test = harness({ config: { analysisEnabled: false } });
  const response = await test.call("not even json");

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
  assertEquals(test.prompts.length, 0);
});

Deno.test("malformed JSON is INVALID_REQUEST and never reaches the AI", async () => {
  const test = harness();
  const response = await test.call("{ not json");

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(test.reserves.length, 0);
});

Deno.test("a contract violation is refused before a slot is taken", async () => {
  const test = harness();
  const response = await test.call(validRequestBody({ ocr_text: "" }));

  assertEquals(response.status, 400);
  // The order matters: parsing is free, the quota is not.
  assertEquals(test.reserves.length, 0);
});

Deno.test("a config read failure is 500, not a silent fallback to enabled", async () => {
  // Falling back to defaults would make the kill switch fail OPEN during the
  // exact incident someone was trying to stop.
  const test = harness({ loadConfig: () => Promise.reject(ApiError.internalError()) });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
  assertEquals(test.prompts.length, 0);
});

// ── quota outcomes ────────────────────────────────────────────────────────

Deno.test("an exhausted quota is 429 with the Cairo reset instant", async () => {
  const test = harness({ reserveOutcome: "limit_reached" });
  const response = await test.call();

  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.error.code, "DAILY_LIMIT_REACHED");
  // Cairo is on EEST in July, so the offset must be +03:00, not a hard-coded +02.
  assertEquals(body.error.details.reset_at, "2026-07-27T00:00:00+03:00");
  // Critical: the AI must not be called, or the limit costs us money anyway.
  assertEquals(test.prompts.length, 0);
});

Deno.test("the configured global cap reaches the store, unlimited by default", async () => {
  // The store cannot enforce a cap it is never told about, and the default must
  // stay null — a dark-launched breaker that silently starts counting would
  // change today's behaviour.
  assertEquals((await reserveInput(harness())).globalDailyCallCap, null);
  assertEquals(
    (await reserveInput(harness({ config: { globalDailyCallCap: 500 } })))
      .globalDailyCallCap,
    500,
  );
});

Deno.test("a tripped global breaker is 429 GLOBAL_CAPACITY_REACHED with no AI call", async () => {
  const test = harness({
    reserveOutcome: "global_capacity_reached",
    config: { globalDailyCallCap: 500 },
  });
  const response = await test.call();

  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.error.code, "GLOBAL_CAPACITY_REACHED");
  // The whole point of the breaker: the provider is never called, so the
  // refusal costs nothing.
  assertEquals(test.prompts.length, 0);
  // Nothing was reserved, so there is nothing to settle — a finalize here would
  // decrement a counter this request never incremented.
  assertEquals(test.finalizes.length, 0);
});

Deno.test("a tripped global breaker is not reported as the user's own limit", async () => {
  // The user may have analysed nothing today. Sending DAILY_LIMIT_REACHED — or
  // a reset_at — would tell them to wait for a quota that is not what ran out.
  const test = harness({ reserveOutcome: "global_capacity_reached" });
  const body = await (await test.call()).json();

  assertEquals(body.error.code === "DAILY_LIMIT_REACHED", false);
  assertEquals("details" in body.error, false);
});

Deno.test("a replayed request id is refused rather than run twice", async () => {
  const test = harness({ reserveOutcome: "duplicate" });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "ANALYSIS_FAILED");
  assertEquals(test.prompts.length, 0);
  assertEquals(test.finalizes.length, 0);
});

// ── failures must cost the user nothing ───────────────────────────────────

Deno.test("an AI timeout releases the slot and answers 408", async () => {
  const test = harness({ analyse: () => Promise.reject(ApiError.timeout()) });
  const response = await test.call();

  assertEquals(response.status, 408);
  assertEquals(await errorCode(response), "TIMEOUT");
  assertEquals(test.finalizes[0].success, false);
  assertEquals(test.finalizes[0].errorCode, "TIMEOUT");
});

Deno.test("an AI rate limit releases the slot and answers 429 AI_RATE_LIMITED", async () => {
  const test = harness({ analyse: () => Promise.reject(ApiError.aiRateLimited()) });
  const response = await test.call();

  assertEquals(response.status, 429);
  assertEquals(await errorCode(response), "AI_RATE_LIMITED");
  assertEquals(test.finalizes[0].success, false);
});

Deno.test("an unusable model answer releases the slot", async () => {
  // A blank title means there is no result screen to show; charging for it
  // would be worse than saying it failed.
  const test = harness({
    analyse: () =>
      Promise.resolve(
        modelAnalysis({
          document_type: { type: "invoice", title: "", confidence: "low" },
        }),
      ),
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "ANALYSIS_FAILED");
  assertEquals(test.finalizes[0].success, false);
});

Deno.test("an unexpected crash mid-analysis still releases the slot", async () => {
  const test = harness({
    analyse: () => Promise.reject(new TypeError("undefined is not a function")),
  });
  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
  assertEquals(test.finalizes[0].success, false);
  // Never the raw message — it can quote the payload that broke.
  assertEquals(test.finalizes[0].errorCode, "INTERNAL_ERROR");
});

Deno.test("an unsupported document is a 200 that costs no quota (§31 rule 6)", async () => {
  const test = harness({
    analyse: () =>
      Promise.resolve(
        modelAnalysis({
          status: "unsupported",
          key_information: [],
          dates: [],
          amounts: [],
        }),
      ),
  });
  const response = await test.call();

  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "unsupported");
  assertEquals(test.finalizes[0].success, false);
});

// ── the validation pipeline is actually wired in ──────────────────────────

Deno.test("a value that is not on the page is downgraded, not returned as fact", async () => {
  const test = harness({
    analyse: () =>
      Promise.resolve(
        modelAnalysis({
          amounts: [
            // 9999.99 appears nowhere in the fixture's OCR text.
            { label: "إجمالي المبلغ", value: 9999.99, currency: "جنيه", confidence: "high" },
          ],
        }),
      ),
  });

  const body = await (await test.call()).json();

  assertEquals(body.amounts[0].confidence, "low");
  // partial, so the result screen shows its review banner.
  assertEquals(body.status, "partial");
  assert(body.missing_fields.includes("amounts"));
});

Deno.test("a medical document always carries its disclaimer", async () => {
  const test = harness({
    analyse: () =>
      Promise.resolve(
        modelAnalysis({
          document_type: { type: "medical", title: "تحليل معملي", confidence: "high" },
          warnings: [],
        }),
      ),
  });

  const body = await (await test.call()).json();

  assert(
    body.warnings.some((warning: { type: string }) => warning.type === "medical"),
    "a medical report must never be shown without the doctor disclaimer",
  );
});

Deno.test("a date already in the past never drives a reminder", async () => {
  const test = harness({
    analyse: () =>
      Promise.resolve(
        modelAnalysis({
          dates: [
            {
              label: "تاريخ الإصدار",
              date: "2026-06-01",
              time: null,
              role: "issued",
              is_reminder_worthy: true,
              confidence: "high",
            },
          ],
        }),
      ),
  });

  const body = await (await test.call()).json();
  assertEquals(body.dates[0].is_reminder_worthy, false);
});

// ── text only (F20-T15) ───────────────────────────────────────────────────
// The image shape F13-T11 added was removed with its Azure/Google pipeline:
// photos are read by `ocr-document`, and only their reviewed text arrives here.

Deno.test("an image-shaped body is INVALID_REQUEST even with online reading on, and takes no slot", async () => {
  const test = harness({ config: { onlineOcrEnabled: true } });
  const response = await test.call(validImageRequestBody());

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(test.reserves.length, 0);
  assertEquals(test.prompts.length, 0);
});

Deno.test("phones and references stay empty on the wire, whatever the candidates carry", async () => {
  // Nothing confirms a phone or reference candidate any more, and a raw regex
  // hit must not reach the user as a finding.
  const test = harness();
  const body = await (await test.call(validRequestBody({
    candidates: {
      dates: [],
      times: [],
      amounts: [],
      phones: [{
        raw_text: "01012345678",
        normalized_number: "+201012345678",
        is_ambiguous: false,
      }],
      references: [{ raw_text: "رقم الحساب 12345678", value: "12345678", is_ambiguous: true }],
    },
  }))).json();

  assertEquals(body.phones, []);
  assertEquals(body.references, []);
});

// ── the analyser is built per request ─────────────────────────────────────
// The handler must not cache the chain: its time budget comes from runtime
// config, and an operator change must take effect on the very next request with
// no redeploy and no worker restart. (F18's provider-order flag, which this
// section used to test, was removed in F20-T04.)

Deno.test("a budget change takes effect on the next request", async () => {
  let aiTimeoutSeconds = 25;
  const test = harness({
    loadConfig: () => Promise.resolve(testConfig({ aiTimeoutSeconds })),
  });

  await test.call();
  aiTimeoutSeconds = 20;
  await test.call();

  assertEquals(test.analyserTimeouts, [25, 20]);
});

Deno.test("the request id reaches the analyser so its provider log correlates", async () => {
  // Without it the `analyze.provider` line could not be tied to the
  // `analyze.completed` line for the same request (F18-T07).
  const test = harness();

  await test.call();

  assertEquals(test.analyserRequestIds, [REQUEST_ID]);
});

// ── the Mistral → Groq chain behind the handler (F20-T11) ─────────────────
// The chain's own rules are pinned in fallback-provider.test.ts. These prove
// what it means for the user's quota: one slot per analysis however many
// providers were asked, and nothing charged when every one of them failed.

/** A leg that answers, or throws, and counts its calls. */
function fakeLeg(outcome: ModelAnalysis | Error) {
  let calls = 0;
  const fn: AnalysisLeg = () => {
    calls += 1;
    return outcome instanceof Error ? Promise.reject(outcome) : Promise.resolve(outcome);
  };
  return {
    fn,
    get calls() {
      return calls;
    },
  };
}

/** The production chain shape, Mistral then Groq, over the given legs. */
function chainOver(mistral: AnalysisLeg, groq: AnalysisLeg) {
  return (timeoutSeconds: number, requestId: string): AiAnalysisProvider =>
    createFallbackAnalysisProvider({
      primary: mistral,
      primaryName: "mistral",
      fallback: groq,
      fallbackName: "groq",
      totalSeconds: timeoutSeconds,
      requestId,
      timeoutSignal: () => new AbortController().signal,
      log: () => {},
    });
}

Deno.test("an analysis Mistral serves takes one slot and never asks Groq", async () => {
  const mistral = fakeLeg(modelAnalysis());
  const groq = fakeLeg(modelAnalysis());
  const test = harness({ createAnalyser: chainOver(mistral.fn, groq.fn) });

  const response = await test.call();

  assertEquals(response.status, 200);
  assertEquals(test.reserves.length, 1);
  assertEquals(test.finalizes, [{ requestId: REQUEST_ID, success: true, errorCode: undefined }]);
  assertEquals(groq.calls, 0);
});

Deno.test("an analysis Groq serves after Mistral fails still takes exactly one slot", async () => {
  // The fallback is a second provider call, not a second analysis: the user
  // asked once and is charged once.
  const mistral = fakeLeg(new ProviderFailure("rate_limited"));
  const groq = fakeLeg(modelAnalysis());
  const test = harness({ createAnalyser: chainOver(mistral.fn, groq.fn) });

  const response = await test.call();

  assertEquals(response.status, 200);
  assertEquals(mistral.calls, 1);
  assertEquals(groq.calls, 1);
  assertEquals(test.reserves.length, 1);
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, true);
});

Deno.test("when both providers fail the slot is released and the last failure answers", async () => {
  const mistral = fakeLeg(new ProviderFailure("rate_limited"));
  const groq = fakeLeg(new ProviderFailure("upstream_unavailable"));
  const test = harness({ createAnalyser: chainOver(mistral.fn, groq.fn) });

  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "ANALYSIS_FAILED");
  assertEquals(test.reserves.length, 1);
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, false);
  assertEquals(test.finalizes[0].errorCode, "ANALYSIS_FAILED");
});

Deno.test("a bad Mistral key releases the slot without ever asking Groq", async () => {
  const mistral = fakeLeg(new ProviderFailure("auth"));
  const groq = fakeLeg(modelAnalysis());
  const test = harness({ createAnalyser: chainOver(mistral.fn, groq.fn) });

  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
  assertEquals(groq.calls, 0);
  assertEquals(test.finalizes[0].success, false);
});

Deno.test("a missing provider credential fails before any slot is reserved (A8)", async () => {
  // What `analyze-document` does when MISTRAL_* or GROQ_* is unset: building
  // the chain throws, and the user's quota is never touched.
  const test = harness({
    createAnalyser: () => {
      throw new Error("MISTRAL_API_KEY is not set.");
    },
  });

  const response = await test.call();

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");
  assertEquals(test.reserves.length, 0);
  assertEquals(test.finalizes.length, 0);
});
