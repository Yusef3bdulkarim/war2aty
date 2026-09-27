/**
 * F06-T09 · Tests for the OpenAI-compatible chat transport.
 *
 * `fetch` is injected, so these run offline and need no API key.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  type ChatCompletionRequest,
  createChatClient,
} from "../../functions/_shared/ai/openai-compatible-client.ts";

/**
 * Deliberately not a real provider's URL. This module is the provider-neutral
 * half of the F18 seam; binding its tests to Groq's endpoint would re-couple
 * exactly what T01 and T03 separated. Each provider's own base URL is tested
 * in its config module's tests.
 */
const BASE_URL = "https://provider.example/v1";

const REQUEST: ChatCompletionRequest = {
  messages: [
    { role: "system", content: "You analyse documents." },
    { role: "user", content: "فاتورة كهرباء بمبلغ 850 جنيه" },
  ],
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function okPayload(content = '{"result":"ok"}') {
  return {
    model: "llama-3.3-70b-versatile",
    choices: [{ message: { content } }],
    usage: { prompt_tokens: 120, completion_tokens: 45 },
  };
}

/** Records what the client sent, and replies with whatever is supplied. */
function recordingFetch(reply: Response | (() => Response | Promise<Response>)) {
  const calls: Array<{ url: string; init: RequestInit }> = [];

  const impl = ((url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return Promise.resolve(typeof reply === "function" ? reply() : reply);
  }) as unknown as typeof fetch;

  return { impl, calls };
}

function client(fetchImpl: typeof fetch, timeoutSeconds = 25) {
  return createChatClient({
    baseUrl: BASE_URL,
    apiKey: "test-key",
    model: "llama-3.3-70b-versatile",
    timeoutSeconds,
    fetchImpl,
  });
}

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("returns the assistant content", async () => {
  const { impl } = recordingFetch(jsonResponse(okPayload("the answer")));

  const completion = await client(impl)(REQUEST);

  assertEquals(completion.content, "the answer");
  assertEquals(completion.model, "llama-3.3-70b-versatile");
  assertEquals(completion.promptTokens, 120);
  assertEquals(completion.completionTokens, 45);
});

Deno.test("sends the key as a bearer token", async () => {
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  const headers = calls[0].init.headers as Record<string, string>;
  assertEquals(headers["Authorization"], "Bearer test-key");
  assertEquals(headers["Content-Type"], "application/json");
});

Deno.test("defaults temperature to 0 for repeatable extraction", async () => {
  // The same paper must read the same way twice; this is not a creative task.
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  assertEquals(JSON.parse(calls[0].init.body as string).temperature, 0);
});

Deno.test("passes the messages through unchanged", async () => {
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  const sent = JSON.parse(calls[0].init.body as string);
  assertEquals(sent.messages, REQUEST.messages);
  // Arabic must survive serialisation intact.
  assertEquals(sent.messages[1].content, "فاتورة كهرباء بمبلغ 850 جنيه");
});

Deno.test("omits optional fields rather than sending undefined", async () => {
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  const sent = JSON.parse(calls[0].init.body as string);
  assertEquals("max_tokens" in sent, false);
  assertEquals("response_format" in sent, false);
  assertEquals("reasoning_effort" in sent, false);
});

Deno.test("forwards a reasoning effort when given one", async () => {
  // `openai/gpt-oss-*` spends part of maxTokens on an internal reasoning
  // trace; this is the seam the analysis provider uses to cap it.
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)({ ...REQUEST, reasoningEffort: "low" });

  const sent = JSON.parse(calls[0].init.body as string);
  assertEquals(sent.reasoning_effort, "low");
});

Deno.test("forwards a response format when given one", async () => {
  // The seam F06-T11 uses for schema-constrained output.
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)({ ...REQUEST, responseFormat: { type: "json_object" } });

  const sent = JSON.parse(calls[0].init.body as string);
  assertEquals(sent.response_format, { type: "json_object" });
});

Deno.test("a per-request model overrides the default", async () => {
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)({ ...REQUEST, model: "other-model" });

  assertEquals(JSON.parse(calls[0].init.body as string).model, "other-model");
});

// ── failures ──────────────────────────────────────────────────────────────

Deno.test("a rate limit becomes AI_RATE_LIMITED", async () => {
  const { impl } = recordingFetch(jsonResponse({ error: "slow down" }, 429));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
  assertEquals((thrown as ApiError).status, 429);
});

Deno.test("a provider 5xx becomes ANALYSIS_FAILED, not a leak", async () => {
  const { impl } = recordingFetch(jsonResponse({ error: "upstream" }, 503));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a provider error body never reaches the caller", async () => {
  // Groq echoes the offending prompt in validation errors — and the prompt is
  // the user's document.
  const leaky = jsonResponse({
    error: { message: "invalid prompt: فاتورة كهرباء 850 جنيه, acct 12345678" },
  }, 400);
  const { impl } = recordingFetch(leaky);

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  const message = (thrown as ApiError).message;
  assert(!message.includes("850"), "amounts must not escape");
  assert(!message.includes("12345678"), "reference numbers must not escape");
  assert(!message.includes("فاتورة"), "document text must not escape");
});

Deno.test("an auth failure is not reported as the user's fault", async () => {
  // A bad GROQ_API_KEY is our deploy problem; the user is not unauthorized.
  const { impl } = recordingFetch(jsonResponse({ error: "bad key" }, 401));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
  assertEquals((thrown as ApiError).status, 500);
});

Deno.test("a timeout becomes TIMEOUT so the slot can be released", async () => {
  const impl = (() =>
    Promise.reject(
      new DOMException("signal timed out", "TimeoutError"),
    )) as unknown as typeof fetch;

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "TIMEOUT");
  assertEquals((thrown as ApiError).status, 408);
});

Deno.test("a dropped connection becomes ANALYSIS_FAILED", async () => {
  const impl = (() => Promise.reject(new TypeError("connection reset"))) as unknown as typeof fetch;

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("an unparseable 200 becomes ANALYSIS_FAILED", async () => {
  const { impl } = recordingFetch(
    new Response("not json", { status: 200 }),
  );

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a 200 with no choices becomes ANALYSIS_FAILED", async () => {
  // A well-formed reply carrying nothing usable is still a failed analysis,
  // and must not be charged to the user.
  for (const payload of [{}, { choices: [] }, { choices: [{ message: {} }] }]) {
    const { impl } = recordingFetch(jsonResponse(payload));
    const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);
    assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
  }
});

Deno.test("an empty completion becomes ANALYSIS_FAILED", async () => {
  const { impl } = recordingFetch(jsonResponse(okPayload("")));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

// ── the timeout itself ────────────────────────────────────────────────────

Deno.test("the request carries an abort signal", async () => {
  // Without one a hung provider would hold the reserved slot until it lapsed,
  // leaving the user on a spinner.
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  assert(calls[0].init.signal instanceof AbortSignal);
});

Deno.test("a real timeout fires and is mapped", async () => {
  // Genuinely wait out a 1s budget rather than faking the abort.
  const slow = ((_url: string, init?: RequestInit) =>
    new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => {
        reject(new DOMException("signal timed out", "TimeoutError"));
      });
    })) as unknown as typeof fetch;

  const thrown = await assertRejects(
    () => client(slow, 1)(REQUEST),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "TIMEOUT");
});

Deno.test("a sub-second timeout is clamped to at least one second", async () => {
  const { impl } = recordingFetch(jsonResponse(okPayload()));

  // Must not become AbortSignal.timeout(0), which aborts immediately.
  const completion = await client(impl, 0)(REQUEST);

  assertEquals(completion.content, '{"result":"ok"}');
});

// ── where the request goes ────────────────────────────────────────────────

Deno.test("the request goes to the configured base URL", async () => {
  // The URL used to be a hardcoded constant (F06-T09). Since F18-T01 it is
  // composed, and composing it is how one transport serves two providers — so
  // the join is worth pinning: no doubled slash, no missing path.
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  assertEquals(calls[0].url, "https://provider.example/v1/chat/completions");
});

// ── every transport failure is a provider fault (F18-T05) ─────────────────
// The fallback chain fails over iff `providerFault` is set, so this is the link
// the whole feature hangs from: drop `.asProviderFault()` from any path below
// and failover silently stops working for it while every other test still
// passes. Each case here pins one path.

Deno.test("a rate limit is marked a provider fault", async () => {
  const { impl } = recordingFetch(new Response("slow down", { status: 429 }));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).providerFault, true);
});

Deno.test("a 5xx is marked a provider fault", async () => {
  const { impl } = recordingFetch(new Response("boom", { status: 503 }));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).providerFault, true);
});

Deno.test("an auth failure is marked a provider fault", async () => {
  // OUR key being wrong is still the provider declining to answer, and the
  // other leg has a different key — so it is worth asking.
  const { impl } = recordingFetch(new Response("bad key", { status: 401 }));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).providerFault, true);
});

Deno.test("a dropped connection is marked a provider fault", async () => {
  const impl = (() =>
    Promise.reject(new TypeError("connection reset"))) as unknown as typeof fetch;

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).providerFault, true);
});

Deno.test("a timeout is marked a provider fault", async () => {
  const impl = (() =>
    Promise.reject(
      new DOMException("signal timed out", "TimeoutError"),
    )) as unknown as typeof fetch;

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).code, "TIMEOUT");
  assertEquals((thrown as ApiError).providerFault, true);
});

Deno.test("an unparseable 200 is marked a provider fault", async () => {
  const { impl } = recordingFetch(new Response("not json", { status: 200 }));

  const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);

  assertEquals((thrown as ApiError).providerFault, true);
});

Deno.test("a 200 carrying no completion is marked a provider fault", async () => {
  // No answer at all, as opposed to an answer of the wrong shape — which is the
  // parser's business and deliberately NOT a provider fault.
  for (const payload of [{}, { choices: [] }, { choices: [{ message: {} }] }]) {
    const { impl } = recordingFetch(jsonResponse(payload));
    const thrown = await assertRejects(() => client(impl)(REQUEST), ApiError);
    assertEquals((thrown as ApiError).providerFault, true);
  }
});
