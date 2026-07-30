/**
 * F13-T04 · Azure AI Document Intelligence transport.
 *
 * The only place that speaks HTTP to Azure. Submits an image to the Read
 * model, polls the async operation to completion, and returns the extracted
 * text. Field extraction (T05) and validation (T06) are layered on top of
 * this, same split as `groq-client.ts` vs `groq-provider.ts`.
 *
 * Azure's analyze API is asynchronous: submit returns 202 with an
 * `Operation-Location` URL, which is polled until `status` leaves
 * "running"/"notStarted". Per the locked decision (§ Locked decisions #3),
 * the result is explicitly deleted right after it is read — Azure's default
 * 24h retention window is not relied on. The delete runs in a `finally`, on
 * its own timeout budget, so a timed-out poll still cleans up the result it
 * created.
 *
 * PRIVACY (§7, §51): no OCR text, prompt, or key is ever logged. Error paths
 * discard the provider's response body without reading it as text.
 */

import { ApiError } from "../errors/api-error.ts";
import type { AzureDocumentIntelligenceOptions } from "./azure-config.ts";

const AZURE_API_VERSION = "2024-11-30";
const AZURE_READ_MODEL_ID = "prebuilt-read";

/** Budget for the delete call, independent of the analyze timeout it follows. */
const DELETE_TIMEOUT_SECONDS = 10;

export interface AzureReadResult {
  /** The full extracted text, in reading order. */
  readonly content: string;
  readonly modelId: string;
}

export interface AzureDocumentIntelligenceClientOptions extends AzureDocumentIntelligenceOptions {
  /** Wall-clock budget for submit + polling combined. */
  readonly timeoutSeconds: number;
  /** Milliseconds between polls. Defaults to 1000. */
  readonly pollIntervalMs?: number;
  /** Injected so tests never touch the network. */
  readonly fetchImpl?: typeof fetch;
}

export type AzureDocumentIntelligenceClient = (
  image: Uint8Array,
  contentType: string,
) => Promise<AzureReadResult>;

interface AzureAnalyzeResultBody {
  status?: string;
  analyzeResult?: { content?: string; modelId?: string };
}

/** Maps a non-2xx Azure response to an `ApiError`. The response body is never read. */
function errorForStatus(status: number): ApiError {
  if (status === 429) return ApiError.aiRateLimited();
  return ApiError.analysisFailed();
}

async function discard(response: Response): Promise<void> {
  await response.body?.cancel();
}

/**
 * Builds a client bound to an endpoint, key and timeout.
 *
 * Submit and every poll share one `AbortSignal.timeout(timeoutSeconds)`, so
 * the whole submit-to-result round trip is bounded — a hung or slow-to-finish
 * analysis fails with `TIMEOUT` instead of holding the caller's reserved
 * analysis slot indefinitely.
 */
export function createAzureDocumentIntelligenceClient(
  options: AzureDocumentIntelligenceClientOptions,
): AzureDocumentIntelligenceClient {
  const {
    endpoint,
    key,
    timeoutSeconds,
    pollIntervalMs = 1000,
    fetchImpl = fetch,
  } = options;

  const analyzeUrl =
    `${endpoint}/documentintelligence/documentModels/${AZURE_READ_MODEL_ID}:analyze` +
    `?api-version=${AZURE_API_VERSION}`;

  return async (image: Uint8Array, contentType: string): Promise<AzureReadResult> => {
    const budget = AbortSignal.timeout(
      Math.max(1, Math.floor(timeoutSeconds)) * 1000,
    );

    let operationLocation: string | undefined;

    try {
      operationLocation = await submit(fetchImpl, analyzeUrl, key, image, contentType, budget);
      return await pollUntilDone(fetchImpl, operationLocation, key, pollIntervalMs, budget);
    } finally {
      if (operationLocation !== undefined) {
        await deleteResult(fetchImpl, operationLocation, key);
      }
    }
  };
}

async function submit(
  fetchImpl: typeof fetch,
  analyzeUrl: string,
  key: string,
  image: Uint8Array,
  contentType: string,
  signal: AbortSignal,
): Promise<string> {
  let response: Response;
  try {
    response = await fetchImpl(analyzeUrl, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": key,
        "Content-Type": contentType,
      },
      // Cast: the lib types reject a bare Uint8Array as BodyInit over a
      // buffer-generic mismatch, even though fetch accepts it at runtime.
      body: image as unknown as BodyInit,
      signal,
    });
  } catch (thrown) {
    throw mapTransportError(thrown);
  }

  if (response.status !== 202) {
    await discard(response);
    throw errorForStatus(response.status);
  }

  // The body carries nothing useful on a 202; only the header matters.
  await discard(response);

  const operationLocation = response.headers.get("Operation-Location");
  if (!operationLocation) {
    // A 202 without this header is a malformed response we cannot poll.
    throw ApiError.analysisFailed();
  }

  return operationLocation;
}

async function pollUntilDone(
  fetchImpl: typeof fetch,
  operationLocation: string,
  key: string,
  pollIntervalMs: number,
  signal: AbortSignal,
): Promise<AzureReadResult> {
  while (true) {
    let response: Response;
    try {
      response = await fetchImpl(operationLocation, {
        method: "GET",
        headers: { "Ocp-Apim-Subscription-Key": key },
        signal,
      });
    } catch (thrown) {
      throw mapTransportError(thrown);
    }

    if (!response.ok) {
      await discard(response);
      throw errorForStatus(response.status);
    }

    let body: AzureAnalyzeResultBody;
    try {
      body = await response.json();
    } catch {
      throw ApiError.analysisFailed();
    }

    if (body.status === "succeeded") {
      const content = body.analyzeResult?.content;
      if (typeof content !== "string" || content.length === 0) {
        // A well-formed "succeeded" carrying no text is still unusable.
        throw ApiError.analysisFailed();
      }
      return { content, modelId: body.analyzeResult?.modelId ?? AZURE_READ_MODEL_ID };
    }

    if (body.status === "failed") {
      throw ApiError.analysisFailed();
    }

    // "notStarted" / "running" — wait and poll again. The next iteration's
    // fetch rejects immediately once `signal` has fired, so no extra timeout
    // check is needed here.
    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
  }
}

/**
 * Best-effort cleanup: deletes the analyze result so it does not sit in
 * Azure's 24h retention window. Runs on its own short timeout, separate from
 * the analyze budget, so it still fires after that budget has expired. Its
 * failure is swallowed rather than thrown — this call is a privacy hardening
 * measure, not the only safeguard (the result also auto-expires), and it must
 * never mask the real outcome of the analysis it is cleaning up after.
 */
async function deleteResult(
  fetchImpl: typeof fetch,
  operationLocation: string,
  key: string,
): Promise<void> {
  try {
    const response = await fetchImpl(operationLocation, {
      method: "DELETE",
      headers: { "Ocp-Apim-Subscription-Key": key },
      signal: AbortSignal.timeout(DELETE_TIMEOUT_SECONDS * 1000),
    });
    await discard(response);
  } catch {
    // Deliberately swallowed — see doc comment above.
  }
}

function mapTransportError(thrown: unknown): ApiError {
  if (thrown instanceof DOMException && thrown.name === "TimeoutError") {
    return ApiError.timeout();
  }
  return ApiError.analysisFailed();
}
