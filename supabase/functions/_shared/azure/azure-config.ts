/**
 * F13-T03 · Azure AI Document Intelligence credentials.
 *
 * Read here, not inline in the client (T04), so a deploy fault is a loud
 * startup error in one place rather than a mysterious failure wherever the
 * first call happens to be made — same contract as `groqOptionsFromEnv`
 * (`../groq/groq-client.ts`): both required values are deploy facts, and
 * both are fatal immediately rather than degrading per request.
 */

export interface AzureDocumentIntelligenceOptions {
  readonly endpoint: string;
  readonly key: string;
}

/**
 * @throws if `AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT` or
 * `AZURE_DOCUMENT_INTELLIGENCE_KEY` is missing or blank. Reachable only once
 * `azureOcrEnabled` is on (F13-T03 runtime-config flag) and the image route
 * is wired (T11) — until then nothing calls this.
 */
export function azureOptionsFromEnv(
  environment: { get(key: string): string | undefined } = Deno.env,
): AzureDocumentIntelligenceOptions {
  const endpoint = environment.get("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT")
    ?.trim();

  if (!endpoint) {
    throw new Error("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT is not set.");
  }

  const key = environment.get("AZURE_DOCUMENT_INTELLIGENCE_KEY")?.trim();

  if (!key) {
    throw new Error("AZURE_DOCUMENT_INTELLIGENCE_KEY is not set.");
  }

  return { endpoint, key };
}
