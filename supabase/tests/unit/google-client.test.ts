/**
 * F13-T07 · Tests for the Google Document AI transport.
 *
 * `fetch` is injected, so these run offline and need no real credentials. A
 * throwaway RSA keypair is generated once at module load: the private half is
 * fed to the client as the "service account key", the public half is used
 * here to independently verify the JWT the client signs, so the test does not
 * just trust the client's own claim of what it sent.
 */

import { assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createGoogleDocumentAiClient } from "../../functions/_shared/google/google-client.ts";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const IMAGE = new Uint8Array([1, 2, 3]);

// ── a throwaway keypair, generated once for the whole file ─────────────────

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64UrlDecode(value: string): Uint8Array {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function pemFromPkcs8(der: ArrayBuffer): string {
  const body = base64Encode(new Uint8Array(der)).match(/.{1,64}/g)!.join("\n");
  return `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----\n`;
}

const keyPair = await crypto.subtle.generateKey(
  {
    name: "RSASSA-PKCS1-v1_5",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256",
  },
  true,
  ["sign", "verify"],
);
const PRIVATE_KEY_PEM = pemFromPkcs8(
  await crypto.subtle.exportKey("pkcs8", keyPair.privateKey),
);

async function verifyAssertion(assertion: string): Promise<boolean> {
  const [headerB64, claimsB64, signatureB64] = assertion.split(".");
  const signingInput = new TextEncoder().encode(`${headerB64}.${claimsB64}`);
  return await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    keyPair.publicKey,
    // Cast: same ArrayBufferLike-vs-ArrayBuffer lib-type mismatch as the
    // client's `importPrivateKey` cast.
    base64UrlDecode(signatureB64) as unknown as BufferSource,
    signingInput,
  );
}

function decodeClaims(assertion: string): Record<string, unknown> {
  const [, claimsB64] = assertion.split(".");
  return JSON.parse(new TextDecoder().decode(base64UrlDecode(claimsB64)));
}

// ── fake transport ──────────────────────────────────────────────────────────

interface Call {
  readonly url: string;
  readonly method: string;
  readonly headers: Record<string, string>;
  readonly body: string;
}

function fakeFetch(
  handler: (call: Call) => Response | Promise<Response>,
): { impl: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];

  const impl = (async (url: string | URL | Request, init?: RequestInit) => {
    const call: Call = {
      url: String(url),
      method: init?.method ?? "GET",
      headers: (init?.headers as Record<string, string>) ?? {},
      body: typeof init?.body === "string" ? init.body : String(init?.body ?? ""),
    };
    calls.push(call);
    return await handler(call);
  }) as unknown as typeof fetch;

  return { impl, calls };
}

function tokenResponse(accessToken = "test-access-token"): Response {
  return new Response(
    JSON.stringify({
      access_token: accessToken,
      expires_in: 3600,
      token_type: "Bearer",
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

function processResponse(text = "بيان استهلاك الكهرباء"): Response {
  return new Response(JSON.stringify({ document: { text } }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function client(fetchImpl: typeof fetch, timeoutSeconds = 25) {
  return createGoogleDocumentAiClient({
    clientEmail: "svc@test-project.iam.gserviceaccount.com",
    privateKey: PRIVATE_KEY_PEM,
    projectId: "test-project",
    location: "eu",
    processorId: "proc-123",
    timeoutSeconds,
    fetchImpl,
  });
}

function routeByUrl(
  handlers: {
    token?: (call: Call) => Response | Promise<Response>;
    process?: (call: Call) => Response | Promise<Response>;
  },
) {
  return fakeFetch((call) => {
    if (call.url === TOKEN_URL) {
      return (handlers.token ?? (() => tokenResponse()))(call);
    }
    return (handlers.process ?? (() => processResponse()))(call);
  });
}

// ── the happy path ────────────────────────────────────────────────────────

Deno.test("authenticates then processes, returning the extracted text", async () => {
  const { impl, calls } = routeByUrl({});

  const result = await client(impl)(IMAGE, "image/jpeg");

  assertEquals(result.content, "بيان استهلاك الكهرباء");
  assertEquals(calls.length, 2);
  assertEquals(calls[0].url, TOKEN_URL);
  assertEquals(
    calls[1].url,
    "https://eu-documentai.googleapis.com/v1/projects/test-project/locations/eu/processors/proc-123:process",
  );
});

Deno.test("the process call carries the access token from the exchange", async () => {
  const { impl, calls } = routeByUrl({
    token: () => tokenResponse("specific-token-xyz"),
  });

  await client(impl)(IMAGE, "image/jpeg");

  const processCall = calls.find((c) => c.url !== TOKEN_URL)!;
  assertEquals(
    processCall.headers["Authorization"],
    "Bearer specific-token-xyz",
  );
});

Deno.test("sends the whole document as base64 with its mime type in one request", async () => {
  const { impl, calls } = routeByUrl({});

  await client(impl)(IMAGE, "image/png");

  const processCall = calls.find((c) => c.url !== TOKEN_URL)!;
  const parsed = JSON.parse(processCall.body);
  assertEquals(parsed.rawDocument.content, btoa(String.fromCharCode(...IMAGE)));
  assertEquals(parsed.rawDocument.mimeType, "image/png");
});

Deno.test("never references the batch/GCS-backed endpoint", async () => {
  const { impl, calls } = routeByUrl({});

  await client(impl)(IMAGE, "image/jpeg");

  for (const call of calls) {
    assertEquals(call.url.includes("batchProcess"), false);
    assertEquals(call.url.includes("storage.googleapis.com"), false);
    assertEquals(call.url.includes("gcsOutputConfig"), false);
  }
});

// ── the JWT assertion itself ──────────────────────────────────────────────

Deno.test("the assertion is signed with the service account's private key", async () => {
  const { impl, calls } = routeByUrl({});

  await client(impl)(IMAGE, "image/jpeg");

  const tokenCall = calls.find((c) => c.url === TOKEN_URL)!;
  const assertion = new URLSearchParams(tokenCall.body).get("assertion")!;
  assertEquals(await verifyAssertion(assertion), true);
});

Deno.test("the assertion carries the service account email, Document AI scope and Google's token audience", async () => {
  const { impl, calls } = routeByUrl({});

  await client(impl)(IMAGE, "image/jpeg");

  const tokenCall = calls.find((c) => c.url === TOKEN_URL)!;
  const assertion = new URLSearchParams(tokenCall.body).get("assertion")!;
  const claims = decodeClaims(assertion);

  assertEquals(claims.iss, "svc@test-project.iam.gserviceaccount.com");
  assertEquals(claims.aud, TOKEN_URL);
  assertEquals(claims.scope, "https://www.googleapis.com/auth/cloud-platform");
  assertEquals((claims.exp as number) - (claims.iat as number), 3600);
});

Deno.test("the token exchange uses the JWT-bearer grant type", async () => {
  const { impl, calls } = routeByUrl({});

  await client(impl)(IMAGE, "image/jpeg");

  const tokenCall = calls.find((c) => c.url === TOKEN_URL)!;
  assertEquals(
    new URLSearchParams(tokenCall.body).get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
});

// ── error mapping ─────────────────────────────────────────────────────────

Deno.test("a 429 on the token exchange becomes AI_RATE_LIMITED", async () => {
  const { impl } = routeByUrl({
    token: () => new Response(null, { status: 429 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
});

Deno.test("a non-2xx on the token exchange becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({
    token: () => new Response(null, { status: 401 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a token response missing access_token becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({
    token: () => new Response(JSON.stringify({ token_type: "Bearer" }), { status: 200 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("an unparseable token response becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({
    token: () => new Response("not json", { status: 200 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a dropped connection on the token exchange becomes ANALYSIS_FAILED", async () => {
  const impl = (() =>
    Promise.reject(
      new TypeError("network error"),
    )) as unknown as typeof fetch;

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a 429 on the process call becomes AI_RATE_LIMITED", async () => {
  const { impl } = routeByUrl({
    process: () => new Response(null, { status: 429 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "AI_RATE_LIMITED");
});

Deno.test("a non-2xx on the process call becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({
    process: () => new Response(null, { status: 503 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a dropped connection on the process call becomes ANALYSIS_FAILED", async () => {
  const { impl } = fakeFetch((call) => {
    if (call.url === TOKEN_URL) return tokenResponse();
    throw new TypeError("network error");
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("an unparseable process response becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({
    process: () => new Response("not json", { status: 200 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("a well-formed response with no document text becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({
    process: () => new Response(JSON.stringify({ document: {} }), { status: 200 }),
  });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

Deno.test("an empty document text becomes ANALYSIS_FAILED", async () => {
  const { impl } = routeByUrl({ process: () => processResponse("") });

  const thrown = await assertRejects(
    () => client(impl)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "ANALYSIS_FAILED");
});

// ── timeouts ──────────────────────────────────────────────────────────────

Deno.test("a real timeout during the process call fires and is mapped", async () => {
  const impl = ((url: string | URL | Request, init?: RequestInit) => {
    if (String(url) === TOKEN_URL) return Promise.resolve(tokenResponse());
    // The process call never resolves on its own — only the shared abort fires it.
    return new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => {
        reject(new DOMException("signal timed out", "TimeoutError"));
      });
    });
  }) as unknown as typeof fetch;

  const thrown = await assertRejects(
    () => client(impl, 1)(IMAGE, "image/jpeg"),
    ApiError,
  );

  assertEquals((thrown as ApiError).code, "TIMEOUT");
});

Deno.test("a sub-second timeout is clamped to at least one second", async () => {
  const { impl } = routeByUrl({});

  // Must not become AbortSignal.timeout(0), which aborts immediately.
  const result = await client(impl, 0)(IMAGE, "image/jpeg");

  assertEquals(result.content.length > 0, true);
});

// ── sanity on the generated test keypair ──────────────────────────────────

Deno.test("a JWT signed with a different key does not verify (sanity check on the test helper)", async () => {
  const otherPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const signingInput = new TextEncoder().encode("header.claims");
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    otherPair.privateKey,
    signingInput,
  );
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    keyPair.publicKey,
    signature,
    signingInput,
  );
  assertNotEquals(verified, true);
});
