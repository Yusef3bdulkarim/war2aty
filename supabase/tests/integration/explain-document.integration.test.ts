/**
 * F36-T19 · Integration tests for the explain-document endpoint.
 *
 * Two levels of proof in one file:
 *
 * 1. **Wire-level tests** hit the real function on a running local stack
 *    (`supabase functions serve`). They prove what no in-process test can:
 *    that `config.toml` routes the function, that `verify_jwt = true` is
 *    enforced by the gateway, and that the explain_enabled gate reaches the
 *    client as a real 503. These skip when the stack is down.
 *
 * 2. **Handler-level tests** compose the real handler pipeline in-process
 *    with fake AI chains — no Docker, no network, no AI bill. They test the
 *    full sequence end to end: auth → config → both gates → parsing →
 *    reservation → reading → explaining → grounding → response building.
 *    These always run.
 *
 * The no-leak assertion (trap #4) is the critical one: the reading text the
 * server extracted from the image must never appear in the serialised
 * response, not as a line, not as a fragment.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { createExplainHandler } from "../../functions/_shared/explain/explain-handler.ts";
import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { DEFAULT_RUNTIME_CONFIG } from "../../functions/_shared/config/runtime-config.ts";
import type {
  GeminiOcrResult,
  OcrImage,
} from "../../functions/_shared/ai/gemini-ocr-client.ts";
import type { ReadingChain } from "../../functions/_shared/ai/reading-chain.ts";
import type { ExplainChain } from "../../functions/_shared/ai/explain-chain.ts";
import type { ExplainPromptInput } from "../../functions/_shared/prompts/explain-prompt.ts";
import type { ModelExplanation } from "../../functions/_shared/schemas/explain-output.schema.ts";
import type {
  FinalizeResult,
  ReservationResult,
  ReserveInput,
  ReserveOutcome,
  SlotStore,
} from "../../functions/_shared/usage/slot-reservation.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import {
  INSTALLATION_ID,
  SESSION_ID,
  validExplainBody,
} from "../fixtures/explain-fixtures.ts";

// ═══════════════════════════════════════════════════════════════════════════
// Wire-level setup — needs `supabase functions serve`
// ═══════════════════════════════════════════════════════════════════════════

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

async function isFunctionsReachable(): Promise<boolean> {
  if (!supabaseUrl || !supabaseAnonKey) return false;
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/health`, {
      signal: AbortSignal.timeout(5000),
    });
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}

const wireSkip = !(await isFunctionsReachable());

async function mintAnonymousToken(): Promise<string> {
  const response = await fetch(`${supabaseUrl}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: supabaseAnonKey!, "Content-Type": "application/json" },
    body: "{}",
  });
  const session = await response.json();
  return session.access_token as string;
}

function explainEndpoint(): string {
  return `${supabaseUrl}/functions/v1/explain-document`;
}

// ═══════════════════════════════════════════════════════════════════════════
// Handler-level setup — always runs, no stack needed
// ═══════════════════════════════════════════════════════════════════════════

const VALID_TOKEN = "integration-test-token";
const USER_ID = "integration-test-user";
const REQUEST_ID = "11111111-2222-3333-4444-555555555555";
const NOW = new Date("2026-11-12T10:00:00Z");

/**
 * A realistic electricity-bill reading with identifiable substrings that
 * must never leak into the response. Longer and more varied than the unit
 * test's fixture: meter numbers, an account number, a subscriber name, an
 * address, kilowatt readings, an amount, and a deadline.
 */
const READING_TEXT = [
  "شركة الكهربا الحكومية",
  "فاتورة استهلاك كهرباء",
  "رقم العداد: 04/152736",
  "رقم الحساب: 8923-7654-1234",
  "اسم المشترك: محمد عبد الرحمن حسن",
  "العنوان: 15 شارع النيل، المعادي",
  "الفترة: من 2026-10-01 إلى 2026-10-31",
  "القراءة السابقة: 45230 كيلووات",
  "القراءة الحالية: 45487 كيلووات",
  "استهلاك الفترة: 257 كيلووات",
  "المبلغ المطلوب: 487.50 جنيه",
  "آخر ميعاد للسداد: 2026-11-30",
  "يرجى السداد في أقرب فرع",
  "للاستفسار: 121",
].join("\n");

/**
 * Substrings of the reading that are unmistakably raw-reading material.
 * The model's explanation may restate the amount or the deadline in its own
 * words — that is the GROUNDED data and is fine. But meter numbers, account
 * numbers, subscriber names, addresses and raw kWh readings have no reason
 * to appear in the explanation, and their presence would prove a leak.
 */
const READING_ONLY_FRAGMENTS = [
  "04/152736",
  "8923-7654-1234",
  "محمد عبد الرحمن حسن",
  "15 شارع النيل",
  "45230",
  "45487",
  "257 كيلووات",
  "شركة الكهربا الحكومية",
];

function fakeModelExplanation(): ModelExplanation {
  return {
    status: "success",
    paper: { title: "فاتورة كهربا" },
    explain: [
      "دي فاتورة كهربا وعليها مبلغ لازم يتدفع.",
      "الاستهلاك في الفترة اللي فاتت عالي شوية.",
    ],
    todo: { required: true, text: "ادفع 487.50 جنيه قبل 2026-11-30." },
    date: { date: "2026-11-30", time: null, text: "آخر ميعاد للسداد" },
    caution: null,
    contact: { name: "خدمة العملاء", phone: "121" },
    place: null,
  };
}

function testConfig(overrides: Partial<RuntimeConfig> = {}): RuntimeConfig {
  return { ...DEFAULT_RUNTIME_CONFIG, explainEnabled: true, ...overrides };
}

interface Harness {
  readonly call: (
    body?: unknown,
    headers?: Record<string, string>,
  ) => Promise<Response>;
  readonly reserves: ReserveInput[];
  readonly finalizes: {
    requestId: string;
    success: boolean;
    errorCode?: string;
  }[];
}

function createHarness(options: {
  readonly config?: Partial<RuntimeConfig>;
  readonly reserveOutcome?: ReserveOutcome;
  readonly readResult?: GeminiOcrResult;
  readonly explainResult?: ModelExplanation;
} = {}): Harness {
  const reserves: ReserveInput[] = [];
  const finalizes: {
    requestId: string;
    success: boolean;
    errorCode?: string;
  }[] = [];
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

  const handler = createEndpoint({
    name: "explain-document",
    method: "POST",
    handle: createExplainHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: () => Promise.resolve(config),
      slots,
      createReader:
        (_stageSeconds: number, _requestId: string): ReadingChain =>
        (_image: OcrImage) =>
          Promise.resolve(options.readResult ?? { text: READING_TEXT }),
      createExplainer:
        (_stageSeconds: number, _requestId: string): ExplainChain =>
        (_input: ExplainPromptInput) =>
          Promise.resolve(options.explainResult ?? fakeModelExplanation()),
      hashInstallation: (id) => Promise.resolve(`hashed:${id.slice(0, 4)}`),
      now: () => NOW,
    }),
  });

  return {
    call: (body = validExplainBody(), headers = {}) =>
      handler(
        new Request("https://example.test/functions/v1/explain-document", {
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
  };
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

// ═══════════════════════════════════════════════════════════════════════════
// WIRE-LEVEL TESTS — config.toml routing, verify_jwt, the gate over HTTP
// ═══════════════════════════════════════════════════════════════════════════

Deno.test({
  name: "[integration][wire] explain-document rejects a call with no token",
  ignore: wireSkip,
  fn: async () => {
    const response = await fetch(explainEndpoint(), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(validExplainBody()),
    });
    await response.body?.cancel();

    // The gateway's `verify_jwt = true` fires before our handler.
    assertEquals(response.status, 401);
  },
});

Deno.test({
  name:
    "[integration][wire] explain-document returns 503 when explain_enabled is false",
  ignore: wireSkip,
  fn: async () => {
    const token = await mintAnonymousToken();
    const response = await fetch(explainEndpoint(), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: supabaseAnonKey!,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(validExplainBody()),
    });

    // explain_enabled is false in the local DB (seeded by F35, never flipped).
    assertEquals(response.status, 503);
    assertEquals((await response.json()).error.code, "ANALYSIS_DISABLED");
  },
});

Deno.test({
  name: "[integration][wire] explain-document answers a CORS preflight",
  ignore: wireSkip,
  fn: async () => {
    const response = await fetch(explainEndpoint(), { method: "OPTIONS" });
    await response.body?.cancel();

    assertEquals(response.status, 204);
    assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
  },
});

Deno.test({
  name: "[integration][wire] explain-document echoes x-request-id on an error",
  ignore: wireSkip,
  fn: async () => {
    const token = await mintAnonymousToken();
    const requestId = crypto.randomUUID();
    const response = await fetch(explainEndpoint(), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: supabaseAnonKey!,
        "Content-Type": "application/json",
        "x-request-id": requestId,
      },
      body: JSON.stringify(validExplainBody()),
    });
    await response.body?.cancel();

    // Even on 503 the correlation header flows through.
    assertEquals(response.headers.get("x-request-id"), requestId);
  },
});

// ═══════════════════════════════════════════════════════════════════════════
// HANDLER-LEVEL TESTS — the full pipeline, end to end, against fakes
// ═══════════════════════════════════════════════════════════════════════════

// ── happy path ────────────────────────────────────────────────────────────

Deno.test("[integration] happy path returns a complete §33 body", async () => {
  const test = createHarness();
  const response = await test.call();

  assertEquals(response.status, 200);
  const body = await response.json();

  // Envelope.
  assertEquals(body.explain_schema_version, "1.0");
  assertEquals(body.session_id, SESSION_ID);
  assertEquals(body.status, "success");

  // Paper and explain — always present.
  assert(typeof body.paper.title === "string" && body.paper.title.length > 0);
  assert(Array.isArray(body.explain) && body.explain.length >= 1);

  // Todo — always present.
  assert(typeof body.todo.required === "boolean");
  assert(typeof body.todo.text === "string" && body.todo.text.length > 0);

  // Optional cards are either objects or null.
  assert(body.date === null || typeof body.date.date === "string");
  assert(body.caution === null || typeof body.caution.text === "string");
  assert(body.contact === null || typeof body.contact.phone === "string");
  assert(body.place === null || typeof body.place.text === "string");

  // The slot was consumed.
  assertEquals(test.finalizes.length, 1);
  assertEquals(test.finalizes[0].success, true);
});

// ── the reading NEVER leaks into the response (trap #4) ──────────────────

Deno.test("[integration] no line of the reading appears in the serialised response (trap #4)", async () => {
  const test = createHarness();
  const response = await test.call();
  const serialised = await response.text();

  for (const line of READING_TEXT.split("\n")) {
    assert(
      !serialised.includes(line),
      `trap #4 violated: a full reading line leaked into the response — "${line}"`,
    );
  }
});

Deno.test("[integration] reading-only fragments are absent from the response (trap #4)", async () => {
  const test = createHarness();
  const response = await test.call();
  const serialised = await response.text();

  for (const fragment of READING_ONLY_FRAGMENTS) {
    assert(
      !serialised.includes(fragment),
      `trap #4 violated: reading fragment leaked — "${fragment}"`,
    );
  }
});

// ── both gates ────────────────────────────────────────────────────────────

Deno.test("[integration] analysisEnabled=false → 503 ANALYSIS_DISABLED, no slot", async () => {
  const test = createHarness({ config: { analysisEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
  assertEquals(test.reserves.length, 0);
});

Deno.test("[integration] explainEnabled=false → 503 ANALYSIS_DISABLED, no slot", async () => {
  const test = createHarness({ config: { explainEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals(await errorCode(response), "ANALYSIS_DISABLED");
  assertEquals(test.reserves.length, 0);
});

// ── schema mismatch ──────────────────────────────────────────────────────

Deno.test("[integration] explain_schema_version '2.0' is refused as UNSUPPORTED_SCHEMA", async () => {
  const test = createHarness();
  const response = await test.call(
    validExplainBody({ explain_schema_version: "2.0" }),
  );

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "UNSUPPORTED_SCHEMA");
  assertEquals(
    test.reserves.length,
    0,
    "a schema mismatch must not reserve a slot",
  );
});

Deno.test("[integration] an analyze-document body shape is refused", async () => {
  const test = createHarness();
  const response = await test.call({
    schema_version: "2.0",
    session_id: SESSION_ID,
    installation_id: INSTALLATION_ID,
    app_version: "1.0.0",
    input_type: "text",
    ocr_text: "test",
    detected_languages: ["ar"],
    candidates: {},
  });

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
});

// ── quota ─────────────────────────────────────────────────────────────────

Deno.test("[integration] daily limit reached → 429 DAILY_LIMIT_REACHED with reset_at", async () => {
  const test = createHarness({ reserveOutcome: "limit_reached" });
  const response = await test.call();

  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.error.code, "DAILY_LIMIT_REACHED");
  assert(
    typeof body.error.details.reset_at === "string",
    "must carry the Cairo-day reset time",
  );
});

Deno.test("[integration] global capacity reached → 429 GLOBAL_CAPACITY_REACHED", async () => {
  const test = createHarness({ reserveOutcome: "global_capacity_reached" });
  const response = await test.call();

  assertEquals(response.status, 429);
  assertEquals(await errorCode(response), "GLOBAL_CAPACITY_REACHED");
});
