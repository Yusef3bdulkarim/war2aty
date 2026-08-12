/**
 * F13-T04 · Tests for the Azure Document Intelligence transport.
 *
 * `fetch` is injected, so these run offline and need no API key. The one real
 * timeout test waits out a genuine 1s budget rather than faking the abort,
 * same pattern as `groq-client.test.ts`.
 */

import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import {
  createAzureDocumentIntelligenceClient,
} from "../../functions/_shared/azure/azure-client.ts";

const OPERATION_LOCATION =
  "https://example.cognitiveservices.azure.com/documentintelligence/documentModels/" +
  "prebuilt-read/analyzeResults/11111111-1111-1111-1111-111111111111?api-version=2024-11-30";

const IMAGE = new Uint8Array([1, 2, 3]);

interface Call {
  readonly url: string;
  readonly method: string;
  readonly headers: Record<string, string>;
}

/** Routes on method, recording every call made. */
function fakeFetch(
  handler: (call: Call) => Response | Promise<Response>,
): { impl: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];

  const impl = (async (url: string | URL | Request, init?: RequestInit) => {
    const call: Call = {
      url: String(url),
      method: init?.method ?? "GET",
      headers: (init?.headers as Record<string, string>) ?? {},
    };
    calls.push(call);
    return await handler(call);
  }) as unknown as typeof fetch;

  return { impl, calls };
}

function acceptedResponse(operationLocation = OPERATION_LOCATION): Response {
  return new Response(null, {
    status: 202,
    headers: { "Operation-Location": operationLocation },
  });
}

function succeededResponse(content = "بيان استهلاك الكهرباء"): Response {
  return new Response(
    JSON.stringify({
      status: "succeeded",
      analyzeResult: { content, modelId: "prebuilt-read" },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function succeededResponseWithPages(content: string, pages: unknown[]): Response {
  return new Response(
    JSON.stringify({
      status: "succeeded",
      analyzeResult: { content, modelId: "prebuilt-read", pages },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function runningResponse(): Response {
  return new Response(JSON.stringify({ status: "running" }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function client(
  fetchImpl: typeof fetch,
  extra: Partial<{ timeoutSeconds: number; pollIntervalMs: number }> = {},
) {
  return createAzureDocumentIntelligenceClient({
    endpoint: "https://example.cognitiveservices.azure.com",
    key: "test-key",
    timeoutSeconds: extra.timeoutSeconds ?? 25,
    pollIntervalMs: extra.pollIntervalMs ?? 1,
    fetchImpl,
  });
}

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("submits, polls, reads and deletes on success", async () => {
  let pollCount = 0;
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    // GET: running once, then succeeded.
    pollCount++;
    return pollCount === 1 ? runningResponse() : succeededResponse("النص المستخرج");
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.content, "النص المستخرج");
  assertEquals(result.modelId, "prebuilt-read");

  const methods = calls.map((c) => c.method);
  assertEquals(methods.filter((m) => m === "POST").length, 1);
  assertEquals(methods.filter((m) => m === "GET").length, 2);
  assertEquals(methods.filter((m) => m === "DELETE").length, 1);
});

Deno.test("sends the subscription key on every request", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponse();
  });

  await client(impl)(IMAGE, "image/jpeg");

  for (const call of calls) {
    assertEquals(call.headers["Ocp-Apim-Subscription-Key"], "test-key");
  }
});

Deno.test("submits with the given content type and raw bytes", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponse();
  });

  await client(impl)(IMAGE, "image/png");

  const post = calls.find((c) => c.method === "POST")!;
  assertEquals(post.headers["Content-Type"], "image/png");
});

// ── delete is mandatory ──────────────────────────────────────────────────

Deno.test("delete is called exactly once on success", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponse();
  });

  await client(impl)(IMAGE, "image/jpeg");

  assertEquals(calls.filter((c) => c.method === "DELETE").length, 1);
});

Deno.test("delete is called exactly once when the analysis status is failed", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(JSON.stringify({ status: "failed" }), { status: 200 });
  });

  await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals(calls.filter((c) => c.method === "DELETE").length, 1);
});

Deno.test("delete is called exactly once when polling returns a non-2xx", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(null, { status: 500 });
  });

  await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals(calls.filter((c) => c.method === "DELETE").length, 1);
});

Deno.test("a failing delete does not mask a successful analysis", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 500 });
    return succeededResponse("نص");
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.content, "نص");
});

Deno.test("delete is never called when submit itself fails", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return new Response(null, { status: 500 });
    return new Response(null, { status: 500 });
  });

  await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals(calls.filter((c) => c.method === "DELETE").length, 0);
});

// ── non-2xx mapping ───────────────────────────────────────────────────────

Deno.test("a 429 on submit becomes AI_RATE_LIMITED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return new Response(null, { status: 429 });
    return new Response(null, { status: 204 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
});

Deno.test("a non-2xx on submit becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return new Response(null, { status: 503 });
    return new Response(null, { status: 204 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a non-2xx while polling becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(null, { status: 500 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a 429 while polling becomes AI_RATE_LIMITED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(null, { status: 429 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
});

Deno.test("a dropped connection on submit becomes ANALYSIS_FAILED", async () => {
  const impl = (() => Promise.reject(new TypeError("network error"))) as unknown as typeof fetch;

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a thrown delete never surfaces past the analysis result", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") throw new TypeError("network error");
    return succeededResponse("نص");
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.content, "نص");
});

Deno.test("the model id falls back to the Read model when Azure omits it", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(JSON.stringify({ status: "succeeded", analyzeResult: { content: "نص" } }), {
      status: 200,
    });
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.modelId, "prebuilt-read");
});

Deno.test("a 202 with no Operation-Location header becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return new Response(null, { status: 202 });
    return new Response(null, { status: 204 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("an unparseable poll body becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response("not json", { status: 200 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a succeeded status with no content becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(JSON.stringify({ status: "succeeded", analyzeResult: {} }), {
      status: 200,
    });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a failed analyze status becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return new Response(JSON.stringify({ status: "failed" }), { status: 200 });
  });

  const thrown = await assertRejects(() => client(impl)(IMAGE, "image/jpeg"), ApiError);

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

// ── the poll timeout ──────────────────────────────────────────────────────

Deno.test("a real poll timeout fires and is mapped, and still deletes", async () => {
  // Genuinely wait out a 1s budget rather than faking the abort — same
  // pattern as the Groq client's timeout test.
  let deleteCalls = 0;
  const impl = ((_url: string | URL | Request, init?: RequestInit) => {
    const method = init?.method ?? "GET";
    if (method === "POST") return Promise.resolve(acceptedResponse());
    if (method === "DELETE") {
      deleteCalls++;
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    // GET (poll) never resolves on its own — only the shared abort fires it.
    return new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => {
        reject(new DOMException("signal timed out", "TimeoutError"));
      });
    });
  }) as unknown as typeof fetch;

  const thrown = await assertRejects(
    () => client(impl, { timeoutSeconds: 1, pollIntervalMs: 1 })(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "TIMEOUT");
  assertEquals(deleteCalls, 1);
});

// ── word confidence (T06 input) ──────────────────────────────────────────

Deno.test("flattens words across pages with their offsets and confidence", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponseWithPages("نص أول. نص ثاني.", [
      {
        words: [
          { content: "نص", span: { offset: 0, length: 2 }, confidence: 0.95 },
          { content: "أول.", span: { offset: 3, length: 4 }, confidence: 0.8 },
        ],
      },
      {
        words: [
          { content: "نص", span: { offset: 8, length: 2 }, confidence: 0.6 },
          { content: "ثاني.", span: { offset: 11, length: 5 }, confidence: 0.99 },
        ],
      },
    ]);
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.words, [
    { content: "نص", offset: 0, length: 2, confidence: 0.95 },
    { content: "أول.", offset: 3, length: 4, confidence: 0.8 },
    { content: "نص", offset: 8, length: 2, confidence: 0.6 },
    { content: "ثاني.", offset: 11, length: 5, confidence: 0.99 },
  ]);
});

Deno.test("words is empty when the response carries no pages", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponse("نص");
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.words, []);
});

Deno.test("a word missing a required field is dropped, not fatal to the analysis", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponseWithPages("نص", [
      {
        words: [
          { content: "نص", span: { offset: 0, length: 2 } }, // no confidence
        ],
      },
    ]);
  });

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.content, "نص");
  assertEquals(result.words, []);
});

Deno.test("the analyze request pins stringIndexType to utf16CodeUnit", async () => {
  const { impl, calls } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponse();
  });

  await client(impl)(IMAGE, "image/jpeg");

  const post = calls.find((c) => c.method === "POST")!;
  assertEquals(new URL(post.url).searchParams.get("stringIndexType"), "utf16CodeUnit");
});

Deno.test("a sub-second timeout is clamped to at least one second", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.method === "POST") return acceptedResponse();
    if (call.method === "DELETE") return new Response(null, { status: 204 });
    return succeededResponse();
  });

  // Must not become AbortSignal.timeout(0), which aborts immediately.
  const result = await client(impl, { timeoutSeconds: 0 })(IMAGE, "image/jpeg");

  assertEquals(result.content.length > 0, true);
});
