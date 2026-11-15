/**
 * F37-T01 · Tests for the ephemeral-token URL the phone is handed.
 *
 * The endpoint name is the whole point here. Google keeps two Live services
 * and each refuses the other's credential, so a token sent to the
 * unconstrained one closes `1008 Permission denied` — at runtime, on the
 * device, after the token has already been minted and spent. Nothing else in
 * the suite would catch it: the handler test injects a canned minter.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { mintEphemeralToken } from "../../functions/_shared/live/gemini-token-client.ts";

const MODEL = "gemini-2.5-flash-native-audio-latest";

function withFetch(
  respond: (url: string, init: RequestInit) => Promise<Response>,
): { restore: () => void; calls: { url: string; init: RequestInit }[] } {
  const calls: { url: string; init: RequestInit }[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return respond(String(input), init ?? {});
  }) as typeof fetch;
  return {
    restore: () => {
      globalThis.fetch = original;
    },
    calls,
  };
}

const minted = () =>
  Promise.resolve(
    new Response(JSON.stringify({ name: "auth_tokens/ephemeral-123" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    }),
  );

Deno.test("the ws url points at the constrained Live service", async () => {
  const stub = withFetch(minted);
  try {
    const result = await mintEphemeralToken({ apiKey: "k", model: MODEL });

    assert(result.ok, "expected the mint to succeed");
    assert(
      result.token.wsUrl.includes("GenerativeService.BidiGenerateContentConstrained"),
      `ephemeral tokens are refused anywhere else, got: ${result.token.wsUrl}`,
    );
  } finally {
    stub.restore();
  }
});

Deno.test("the ws url carries the token and the requested api version", async () => {
  const stub = withFetch(minted);
  try {
    const result = await mintEphemeralToken({
      apiKey: "k",
      model: MODEL,
      apiVersion: "v1alpha",
    });

    assert(result.ok);
    assert(result.token.wsUrl.includes("generativelanguage.v1alpha.GenerativeService"));
    assert(result.token.wsUrl.includes("access_token=auth_tokens%2Fephemeral-123"));
    assertEquals(result.token.model, `models/${MODEL}`);
  } finally {
    stub.restore();
  }
});

Deno.test("the api key goes in the header, never the url", async () => {
  const stub = withFetch(minted);
  try {
    await mintEphemeralToken({ apiKey: "super-secret", model: MODEL });

    assertEquals(stub.calls.length, 1);
    assert(!stub.calls[0].url.includes("super-secret"));
    assertEquals(
      (stub.calls[0].init.headers as Record<string, string>)["x-goog-api-key"],
      "super-secret",
    );
  } finally {
    stub.restore();
  }
});

Deno.test("a 429 is classified as rate limited, not a generic failure", async () => {
  const stub = withFetch(() => Promise.resolve(new Response("", { status: 429 })));
  try {
    const result = await mintEphemeralToken({ apiKey: "k", model: MODEL });

    assert(!result.ok);
    assertEquals(result.reason, "rate_limited");
  } finally {
    stub.restore();
  }
});
