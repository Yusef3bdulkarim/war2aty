/**
 * Lists the Gemma models this Gemini API key can call, with their exact ids
 * (use one as GEMMA_MODEL). Prints no key.
 *
 *   deno run --allow-net --allow-env --env-file=supabase/.env \
 *     supabase/tools/list-gemma-models.ts
 */
const key = Deno.env.get("GEMINI_API_KEY")?.trim();
if (!key) throw new Error("GEMINI_API_KEY is not set.");

const response = await fetch(
  "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000",
  { headers: { "x-goog-api-key": key } },
);
if (!response.ok) throw new Error(`ListModels answered HTTP ${response.status}.`);

const body = await response.json() as {
  models?: { name: string; displayName?: string; supportedGenerationMethods?: string[] }[];
};
const gemma = (body.models ?? []).filter((m) => m.name.toLowerCase().includes("gemma"));
if (gemma.length === 0) console.log("No Gemma models visible to this key.");
for (const m of gemma) {
  console.log(`${m.name.replace(/^models\//, "")}  —  ${m.displayName ?? ""}`);
}
