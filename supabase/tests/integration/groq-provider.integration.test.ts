/**
 * F06-T11 · Schema-constrained analysis against the real model.
 *
 * This is the test the task exists for. With `json_object` mode the model was
 * observed returning correct facts in an entirely invented structure —
 * `"status": "complete"`, flat fields, none of §30. These calls prove the
 * `json_schema` constraint actually holds on the configured model.
 *
 * Requires GROQ_API_KEY; skips otherwise. Kept to three calls.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createGroqClient, DEFAULT_GROQ_MODEL } from "../../functions/_shared/groq/groq-client.ts";
import { createGroqAnalysisProvider } from "../../functions/_shared/groq/groq-provider.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";

const apiKey = Deno.env.get("GROQ_API_KEY");
const model = Deno.env.get("GROQ_MODEL") ?? DEFAULT_GROQ_MODEL;
const skip = !apiKey;

/**
 * The tier allows 8000 tokens/minute and `max_tokens` is reserved against it,
 * so a handful of analyses in quick succession WILL be rate-limited. That is
 * an environment condition, not a defect, and it must not be reported as a
 * failing test — but it must not pass silently either.
 *
 * Retries once after the reset window, then reports the run as skipped.
 */
async function withRateLimitTolerance(
  name: string,
  run: () => Promise<void>,
): Promise<void> {
  try {
    await run();
    return;
  } catch (thrown) {
    if (!(thrown instanceof ApiError) || thrown.code !== "AI_RATE_LIMITED") {
      throw thrown;
    }
  }

  console.warn(`  rate-limited, waiting for the token window before retrying: ${name}`);
  await new Promise((resolve) => setTimeout(resolve, 62_000));

  try {
    await run();
  } catch (thrown) {
    if (thrown instanceof ApiError && thrown.code === "AI_RATE_LIMITED") {
      console.warn(`  SKIPPED (still rate-limited): ${name}`);
      return;
    }
    throw thrown;
  }
}

const NO_CANDIDATES: ExtractedCandidates = {
  dates: [],
  times: [],
  amounts: [],
  phones: [],
  references: [],
};

function provider() {
  return createGroqAnalysisProvider({
    client: createGroqClient({ apiKey: apiKey!, model, timeoutSeconds: 25 }),
  });
}

const CONFIDENCES = ["high", "medium", "low"];

const ELECTRICITY_BILL = [
  "شركة جنوب القاهرة لتوزيع الكهرباء",
  "فاتورة استهلاك كهرباء",
  "رقم الحساب: 12345678",
  "عن شهر: مارس 2026",
  "قيمة الفاتورة: 850.50 جنيه",
  "آخر موعد للسداد: 2026/04/15",
  "يمكن السداد من خلال فوري او ماكينات الدفع",
].join("\n");

Deno.test({
  name: "[integration] a real bill comes back in the contract shape",
  ignore: skip,
  fn: () =>
    withRateLimitTolerance("real bill", async () => {
      const result = await provider()({
        ocrText: ELECTRICITY_BILL,
        detectedLanguages: ["ar"],
        candidates: NO_CANDIDATES,
      });

      // Shape: guaranteed by the schema, asserted because that guarantee is
      // the deliverable.
      assert(["success", "partial", "unsupported"].includes(result.status));
      assert(CONFIDENCES.includes(result.document_type.confidence));
      assert(result.summary.short.length > 0);
      for (const collection of [result.dates, result.amounts, result.key_information]) {
        assert(Array.isArray(collection));
      }

      // Content: coarse, because a model is not deterministic. An electricity
      // bill should not be classified as a medical report.
      assertEquals(result.document_type.type, "invoice");

      // The amount is on the page; it must be read, not invented.
      const amounts = result.amounts.map((amount) => amount.value);
      assert(
        amounts.includes(850.5),
        `expected the printed 850.50 among ${JSON.stringify(amounts)}`,
      );

      // Dates must be ISO, which the prompt demands and §30 requires.
      for (const date of result.dates) {
        assert(
          /^\d{4}-\d{2}-\d{2}$/.test(date.date),
          `expected ISO-8601, got ${date.date}`,
        );
        assert(date.time === null || /^([01]\d|2[0-3]):[0-5]\d$/.test(date.time));
        assertEquals(typeof date.is_reminder_worthy, "boolean");
      }
    }),
});

Deno.test({
  name: "[integration] a sparse document does not invent facts",
  ignore: skip,
  fn: () =>
    withRateLimitTolerance("sparse document", async () => {
      // Almost nothing to read. The failure mode this app must not have is
      // filling the gaps with plausible-looking numbers.
      const result = await provider()({
        ocrText: "ورقة\nغير واضحة",
        detectedLanguages: ["ar"],
        candidates: NO_CANDIDATES,
      });

      assert(["success", "partial", "unsupported"].includes(result.status));
      assertEquals(result.amounts.length, 0, "no amount is printed, so none may be reported");
      assertEquals(result.dates.length, 0, "no date is printed, so none may be reported");
    }),
});

Deno.test({
  name: "[integration] the structure holds even for an out-of-scope document",
  ignore: skip,
  fn: () =>
    withRateLimitTolerance("out-of-scope document", async () => {
      // A shopping list is not a supported document, but the answer must still
      // be well-formed so the client can render the fallback.
      const result = await provider()({
        ocrText: "عيش\nلبن\nجبنة\nطماطم",
        detectedLanguages: ["ar"],
        candidates: NO_CANDIDATES,
      });

      assert(["success", "partial", "unsupported"].includes(result.status));
      assert(result.summary.short.length > 0);
      assert(Array.isArray(result.missing_fields));
    }),
});
