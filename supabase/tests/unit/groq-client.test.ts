/**
 * F06-T09 · Tests for the Groq transport.
 *
 * `fetch` is injected, so these run offline and need no API key.
 */

import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  createGroqClient,
  DEFAULT_GROQ_MODEL,
  type GroqCompletionRequest,
  groqOptionsFromEnv,
} from "../../functions/_shared/groq/groq-client.ts";

const REQUEST: GroqCompletionRequest = {
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
  return createGroqClient({
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

// ── reading the environment ───────────────────────────────────────────────
// The model is the one setting that cannot be guessed: F06-T11 sends
// `response_format: json_schema` on every call, and a model without support
// answers 400 — which reaches the user as ANALYSIS_FAILED, indistinguishable
// from a provider outage. These pin the "fail at startup, never fall back"
// contract that keeps a config slip from becoming a silent total outage.

/** Runs `body` with the Groq env vars set to `values`, then restores them. */
function withEnv(values: Record<string, string | null>, body: () => void) {
  const previous = new Map<string, string | undefined>();

  for (const [key, value] of Object.entries(values)) {
    previous.set(key, Deno.env.get(key));
    if (value === null) Deno.env.delete(key);
    else Deno.env.set(key, value);
  }

  try {
    body();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

Deno.test("the default model supports json_schema", () => {
  // Guards the constant itself: it is what a directly-constructed client and
  // the live integration tests fall back to, so it must never drift to a model
  // that cannot be schema-constrained.
  assert(DEFAULT_GROQ_MODEL.startsWith("openai/gpt-oss-"));
});

Deno.test("options are read from the environment", () => {
  withEnv({ GROQ_API_KEY: "test-key", GROQ_MODEL: "openai/gpt-oss-20b" }, () => {
    const options = groqOptionsFromEnv(25);

    assertEquals(options.apiKey, "test-key");
    assertEquals(options.model, "openai/gpt-oss-20b");
    assertEquals(options.timeoutSeconds, 25);
  });
});

Deno.test("a missing api key is fatal", () => {
  withEnv({ GROQ_API_KEY: null, GROQ_MODEL: "openai/gpt-oss-120b" }, () => {
    assertThrows(() => groqOptionsFromEnv(25), Error, "GROQ_API_KEY");
  });
});

Deno.test("a missing model is fatal rather than defaulted", () => {
  withEnv({ GROQ_API_KEY: "test-key", GROQ_MODEL: null }, () => {
    assertThrows(() => groqOptionsFromEnv(25), Error, "GROQ_MODEL");
  });
});

Deno.test("a blank model is fatal too", () => {
  // `??` would have accepted "" as a set value and sent an empty model name.
  withEnv({ GROQ_API_KEY: "test-key", GROQ_MODEL: "   " }, () => {
    assertThrows(() => groqOptionsFromEnv(25), Error, "GROQ_MODEL");
  });
});

Deno.test("a model is trimmed before use", () => {
  // A trailing newline is what a copy-pasted `.env` value actually looks like.
  withEnv({ GROQ_API_KEY: "test-key", GROQ_MODEL: "openai/gpt-oss-120b\n" }, () => {
    assertEquals(groqOptionsFromEnv(25).model, "openai/gpt-oss-120b");
  });
});
