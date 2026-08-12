/**
 * F13-T03 · Google Document AI service-account credentials.
 *
 * Read here, not inline in the client (T07), so a deploy fault is a loud
 * startup error in one place — same contract as `azureOptionsFromEnv`
 * (`../azure/azure-config.ts`) and `groqOptionsFromEnv`
 * (`../groq/groq-client.ts`).
 */

export interface GoogleDocumentAiOptions {
  readonly clientEmail: string;
  readonly privateKey: string;
  readonly projectId: string;
  readonly location: string;
  readonly processorId: string;
}

function requireEnv(
  environment: { get(key: string): string | undefined },
  key: string,
): string {
  const value = environment.get(key)?.trim();

  if (!value) {
    throw new Error(`${key} is not set.`);
  }

  return value;
}

/**
 * @throws if any of the five env vars below is missing or blank.
 * Reachable only once `azureOcrEnabled` is on and the cross-provider
 * validator (T08) decides a second opinion is needed — until then nothing
 * calls this.
 */
export function googleDocumentAiOptionsFromEnv(
  environment: { get(key: string): string | undefined } = Deno.env,
): GoogleDocumentAiOptions {
  return {
    clientEmail: requireEnv(environment, "GOOGLE_DOCUMENT_AI_CLIENT_EMAIL"),
    // The PEM comes from a downloaded service-account JSON key, where real
    // line breaks are escaped as literal "\n" — a .env file cannot hold a
    // multi-line value. Unescaped once, here, so the JWT signer (T07) never
    // has to remember to do it before using the key.
    privateKey: requireEnv(environment, "GOOGLE_DOCUMENT_AI_PRIVATE_KEY")
      .replace(/\\n/g, "\n"),
    projectId: requireEnv(environment, "GOOGLE_DOCUMENT_AI_PROJECT_ID"),
    location: requireEnv(environment, "GOOGLE_DOCUMENT_AI_LOCATION"),
    processorId: requireEnv(environment, "GOOGLE_DOCUMENT_AI_PROCESSOR_ID"),
  };
}
