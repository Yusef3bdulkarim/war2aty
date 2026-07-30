/**
 * F06-T12 · The pipeline against real model output.
 *
 * The unit tests prove the rules fire on planted input. This proves the
 * opposite and equally important thing: that they do NOT fire on a genuine
 * analysis. A validator that downgrades correct facts would put «قراءة غير
 * مؤكدة» on every value and make the app useless in a quieter way than one
 * that lets hallucinations through.
 *
 * Requires GROQ_API_KEY; skips otherwise. One call.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createGroqClient, DEFAULT_GROQ_MODEL } from "../../functions/_shared/groq/groq-client.ts";
import { createGroqAnalysisProvider } from "../../functions/_shared/groq/groq-provider.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";
import { validateAnalysis } from "../../functions/_shared/validators/validation-pipeline.ts";

const apiKey = Deno.env.get("GROQ_API_KEY");
const model = Deno.env.get("GROQ_MODEL") ?? DEFAULT_GROQ_MODEL;
const skip = !apiKey;

const NO_CANDIDATES: ExtractedCandidates = {
  dates: [],
  times: [],
  amounts: [],
  phones: [],
  references: [],
};

// Deliberately far in the future so the deadline is not "in the past" whenever
// this test is next run.
const BILL = [
  "شركة جنوب القاهرة لتوزيع الكهرباء",
  "فاتورة استهلاك كهرباء",
  "رقم الحساب: 12345678",
  "قيمة الفاتورة: 850.50 جنيه",
  "آخر موعد للسداد: 2030/04/15",
].join("\n");

Deno.test({
  name: "[integration] a genuine analysis passes validation intact",
  ignore: skip,
  fn: async () => {
    const provider = createGroqAnalysisProvider({
      client: createGroqClient({ apiKey: apiKey!, model, timeoutSeconds: 25 }),
    });

    let raw;
    try {
      raw = await provider({
        ocrText: BILL,
        detectedLanguages: ["ar"],
        candidates: NO_CANDIDATES,
      });
    } catch (thrown) {
      if (thrown instanceof ApiError && thrown.code === "AI_RATE_LIMITED") {
        console.warn("  SKIPPED (rate-limited)");
        return;
      }
      throw thrown;
    }

    const { analysis, report } = validateAnalysis({
      analysis: raw,
      ocrText: BILL,
      candidates: NO_CANDIDATES,
      now: new Date(),
    });

    // The printed amount must survive verification at full confidence.
    const total = analysis.amounts.find((amount) => amount.value === 850.5);
    assert(total !== undefined, "the printed 850.50 should have been reported");
    assertEquals(
      total.confidence !== "low",
      true,
      "a correctly read amount must not be downgraded",
    );

    // Nothing that was genuinely on the page should have been dropped.
    assertEquals(report.droppedAmounts, 0);

    // Every surviving date must be well formed, because the pipeline nulls or
    // downgrades anything that is not.
    for (const date of analysis.dates) {
      assert(/^\d{4}-\d{2}-\d{2}$/.test(date.date), `bad date ${date.date}`);
      assert(date.time === null || /^([01]\d|2[0-3]):[0-5]\d$/.test(date.time));
    }

    // The page states no time, so no date may claim one.
    assertEquals(
      analysis.dates.every((date) => date.time === null),
      true,
      "the page states no time, so none may be reported",
    );
  },
});
