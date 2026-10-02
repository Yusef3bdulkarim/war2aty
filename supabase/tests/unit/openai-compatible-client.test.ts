/**
 * F06-T09 · Tests for the OpenAI-compatible chat transport.
 *
 * `fetch` is injected, so these run offline and need no API key.
 *
 * Since F20-T04 every failure is a `ProviderFailure` whose `kind` decides
 * fallback eligibility and the §31 code further up (failure matrix §1). Each
 * failure path therefore pins its kind: getting one wrong silently changes
 * whether a second provider is asked.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import {
  type ChatCompletionRequest,
  createChatClient,
} from "../../functions/_shared/ai/openai-compatible-client.ts";
import {
  ProviderFailure,
  type ProviderFailureKind,
} from "../../functions/_shared/ai/provider-failure.ts";

/**
 * Deliberately not a real provider's URL. This module is the provider-neutral
 * half of the seam; each provider's own base URL is tested in its config
 * module's tests.
 */
const BASE_URL = "https://provider.example/v1";

/** A signal that never fires, for tests that are not about time. */
const OPEN_SIGNAL = new AbortController().signal;

const REQUEST: ChatCompletionRequest = {
  messages: [
    { role: "system", content: "You analyse documents." },
    { role: "user", content: "فاتورة كهرباء بمبلغ 850 جنيه" },
  ],
  signal: OPEN_SIGNAL,
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function okPayload(content = '{"result":"ok"}', finishReason = "stop") {
  return {
    model: "llama-3.3-70b-versatile",
    choices: [{ message: { content }, finish_reason: finishReason }],
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

function client(fetchImpl: typeof fetch) {
  return createChatClient({
    baseUrl: BASE_URL,
    apiKey: "test-key",
    model: "llama-3.3-70b-versatile",
    fetchImpl,
  });
}

/** Runs one request expecting a `ProviderFailure`, and returns its kind. */
async function failureKind(
  fetchImpl: typeof fetch,
  request: ChatCompletionRequest = REQUEST,
): Promise<ProviderFailureKind> {
  const thrown = await assertRejects(() => client(fetchImpl)(request), ProviderFailure);
  return (thrown as ProviderFailure).kind;
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
  // The signal bounds the call; it is never part of the body.
  assertEquals("signal" in sent, false);
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

Deno.test("a completion with no finish_reason is still an answer", async () => {
  // Not every OpenAI-compatible provider sends one; only "length" is a failure.
  const { impl } = recordingFetch(jsonResponse({ choices: [{ message: { content: "{}" } }] }));

  const completion = await client(impl)(REQUEST);

  assertEquals(completion.content, "{}");
});

// ── HTTP failures, classified (matrix rows A1, A2, A6, A7) ────────────────

Deno.test("a rate limit is rate_limited", async () => {
  const { impl } = recordingFetch(jsonResponse({ error: "slow down" }, 429));

  assertEquals(await failureKind(impl), "rate_limited");
});

Deno.test("a provider 5xx is upstream_unavailable", async () => {
  const { impl } = recordingFetch(jsonResponse({ error: "upstream" }, 503));

  assertEquals(await failureKind(impl), "upstream_unavailable");
});

Deno.test("a bad key is auth, not the user's fault and never a fallback", async () => {
  // A bad key is OUR deploy problem. It must not be hidden behind a second
  // provider (A6) and must not tell the user they are unauthorized.
  const { impl } = recordingFetch(jsonResponse({ error: "bad key" }, 401));

  assertEquals(await failureKind(impl), "auth");
});

Deno.test("a 404 (a wrong model name) is bad_request", async () => {
  const { impl } = recordingFetch(jsonResponse({ error: { code: "model_not_found" } }, 404));

  assertEquals(await failureKind(impl), "bad_request");
});

Deno.test("an ordinary 400 is bad_request", async () => {
  const { impl } = recordingFetch(
    jsonResponse({ error: { code: "invalid_request_error", message: "bad field" } }, 400),
  );

  assertEquals(await failureKind(impl), "bad_request");
});

Deno.test("a 400 with an unreadable body is bad_request", async () => {
  const { impl } = recordingFetch(new Response("<html>nope</html>", { status: 400 }));

  assertEquals(await failureKind(impl), "bad_request");
});

Deno.test("Groq's json_validate_failed 400 is invalid_output, not bad_request", async () => {
  // Groq rejects a completion that failed ITS OWN strict-schema check with a
  // 400. The request was fine; the model's answer was not. That makes it a
  // candidate for a second provider (A5), where bad_request never is (A7).
  const { impl } = recordingFetch(
    jsonResponse({
      error: {
        message: "Generated JSON does not match the expected schema.",
        type: "invalid_request_error",
        code: "json_validate_failed",
        failed_generation: '[{"status":"success"}]',
      },
    }, 400),
  );

  assertEquals(await failureKind(impl), "invalid_output");
});

Deno.test("a provider error body never reaches the caller", async () => {
  // Groq echoes the offending prompt in validation errors — and the prompt is
  // the user's document.
  const leaky = jsonResponse({
    error: {
      code: "json_validate_failed",
      message: "invalid prompt: فاتورة كهرباء 850 جنيه, acct 12345678",
      failed_generation: "acct 12345678",
    },
  }, 400);
  const { impl } = recordingFetch(leaky);

  const thrown = await assertRejects(() => client(impl)(REQUEST), ProviderFailure);

  const message = (thrown as ProviderFailure).message;
  assert(!message.includes("850"), "amounts must not escape");
  assert(!message.includes("12345678"), "reference numbers must not escape");
  assert(!message.includes("فاتورة"), "document text must not escape");
});

// ── transport failures (A3, A4) ───────────────────────────────────────────

Deno.test("a timeout is timeout, so the slot can be released with a 408", async () => {
  const impl = (() =>
    Promise.reject(
      new DOMException("signal timed out", "TimeoutError"),
    )) as unknown as typeof fetch;

  assertEquals(await failureKind(impl), "timeout");
});

Deno.test("a dropped connection is network", async () => {
  const impl = (() => Promise.reject(new TypeError("connection reset"))) as unknown as typeof fetch;

  assertEquals(await failureKind(impl), "network");
});

Deno.test("an abort that is not a timeout is network, not timeout", async () => {
  const impl =
    (() => Promise.reject(new DOMException("aborted", "AbortError"))) as unknown as typeof fetch;

  assertEquals(await failureKind(impl), "network");
});

// ── unusable 200s (A5) ────────────────────────────────────────────────────

Deno.test("an unparseable 200 is invalid_output", async () => {
  const { impl } = recordingFetch(new Response("not json", { status: 200 }));

  assertEquals(await failureKind(impl), "invalid_output");
});

Deno.test("a 200 with no choices is invalid_output", async () => {
  // A well-formed reply carrying nothing usable is still a failed analysis,
  // and must not be charged to the user.
  for (const payload of [{}, { choices: [] }, { choices: [{ message: {} }] }]) {
    const { impl } = recordingFetch(jsonResponse(payload));
    assertEquals(await failureKind(impl), "invalid_output");
  }
});

Deno.test("an empty completion is invalid_output", async () => {
  const { impl } = recordingFetch(jsonResponse(okPayload("")));

  assertEquals(await failureKind(impl), "invalid_output");
});

Deno.test("a completion cut off at max_tokens is invalid_output", async () => {
  // Whatever arrived is at best a prefix of the answer, even when, as here, it
  // happens to parse. A truncated answer is never trusted.
  const { impl } = recordingFetch(jsonResponse(okPayload('{"status":"success"}', "length")));

  assertEquals(await failureKind(impl), "invalid_output");
});

// ── the signal ────────────────────────────────────────────────────────────

Deno.test("the caller's signal is the one the request carries", async () => {
  // No timeout of its own: one request-wide budget governs every attempt
  // (timeout contract §2).
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));
  const controller = new AbortController();

  await client(impl)({ ...REQUEST, signal: controller.signal });

  assertEquals(calls[0].init.signal, controller.signal);
});

Deno.test("a signal that fires mid-request is reported as timeout", async () => {
  // Genuinely wait for the abort rather than faking the rejection.
  const slow = ((_url: string, init?: RequestInit) =>
    new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => reject(init.signal?.reason));
    })) as unknown as typeof fetch;

  assertEquals(
    await failureKind(slow, { ...REQUEST, signal: AbortSignal.timeout(10) }),
    "timeout",
  );
});

// ── where the request goes ────────────────────────────────────────────────

Deno.test("the request goes to the configured base URL", async () => {
  // Composing the URL is how one transport serves every provider, so the join
  // is worth pinning: no doubled slash, no missing path.
  const { impl, calls } = recordingFetch(jsonResponse(okPayload()));

  await client(impl)(REQUEST);

  assertEquals(calls[0].url, "https://provider.example/v1/chat/completions");
});
