/**
 * F36-T11 · The explaining chain — one reading, up to three models, one
 * `ModelExplanation`.
 *
 * The order is D-settled: `ministral-14b` → `gpt-oss-120b` → Gemma 4 26B. Each
 * leg is the same prompt (`explain-prompt.ts`) and the same strict schema
 * (`explain-output.schema.ts`) over a different transport, so this file is
 * wiring: it names the legs, says the stage's log event and its §31 mapping,
 * and hands routing and time to {@link createLegChain}.
 *
 * - Legs 1 and 2 are OpenAI-compatible chat clients (Mistral, Groq).
 * - Leg 3 is Gemma over the Gemini API's NATIVE `generateContent`
 *   (`gemma-native-client.ts`), because the OpenAI-compatible endpoint did not
 *   enforce the schema for Gemma 4. It is a `ChatClient` too, so it needs no
 *   special case here.
 *
 * ── ⚠ The Gemma leg rests on an unmeasured premise (trap #2) ──────────────
 * That Gemma 4 honours `responseJsonSchema` is what `gemma-native-client.ts`
 * says it "exists to measure", and T18's benchmark is where it is measured.
 * Until then the leg is OPTIONAL: a chain of two real legs is an acceptable
 * outcome, and a caller that has not seen T18's answer should not pass one.
 * If the premise is false the leg answers free-form JSON, fails
 * {@link assertModelExplanation} as `invalid_output`, and the chain simply
 * ends on that failure — loud, but a decorative third leg. The nullable-object
 * cards (T09's note) carry the same unmeasured risk per provider.
 *
 * ── Shape is checked, length and truth are not ────────────────────────────
 * {@link assertModelExplanation} confirms the answer is a `ModelExplanation`.
 * It does not enforce §33's caps or ground a single value: that is T12, which
 * needs the reading. A failure here is `invalid_output` (matrix row A5), so
 * the next model gets its chance at the same page.
 *
 * ── Time ──────────────────────────────────────────────────────────────────
 * D4 gave explaining 20 s of the request's 30. The cap and floor are sized so
 * that all three legs are reachable when the first two hang: 8 s + 8 s leaves
 * 4 s, above {@link DEFAULT_EXPLAIN_MIN_FALLBACK_MS}. They are defaults, not
 * measurements — the analysis chain's Mistral p95 of 12.7 s was for a much
 * larger answer than a ≤ 850-character page — and T18 records real latency.
 *
 * PRIVACY (§7, §51): the reading is the user's document. Nothing here logs it,
 * the prompt, or the answer; failures never carry the model's content.
 */

import type { ChatClient } from "./openai-compatible-client.ts";
import {
  type ChainLeg,
  createLegChain,
  type LegChainOptions,
  type ProviderName,
} from "./leg-chain.ts";
import { analysisApiErrorFor, ProviderFailure } from "./provider-failure.ts";
import { buildExplainMessages, type ExplainPromptInput } from "../prompts/explain-prompt.ts";
import {
  EXPLAIN_RESPONSE_FORMAT,
  type ModelExplanation,
} from "../schemas/explain-output.schema.ts";

/** The explaining stage's share of D4's 30 s budget (reading has the other 10). */
export const DEFAULT_EXPLAIN_STAGE_SECONDS = 20;

/** The longest one explanation may run. See the header: derived, not measured. */
export const DEFAULT_EXPLAIN_ATTEMPT_CAP_MS = 8_000;

/** The least time worth starting a further explanation with. */
export const DEFAULT_EXPLAIN_MIN_FALLBACK_MS = 3_000;

/** Kept apart from the reading stage's `explain.read`, for the same reason. */
export const EXPLAIN_EVENT = "explain.write";

/**
 * Bounded like the analysis leg's, and for the same quota reason: `max_tokens`
 * is reserved against the per-minute token budget, not merely a cap. A page of
 * at most 850 Arabic characters plus the JSON around it is well under this,
 * while it still stops a looping model from burning the whole timeout.
 */
const MAX_OUTPUT_TOKENS = 1500;

/** One model, one attempt. Throws only `ProviderFailure`. */
export type ExplainLeg = (
  input: ExplainPromptInput,
  signal: AbortSignal,
) => Promise<ModelExplanation>;

/** Reading in, explanation out. Throws only `ApiError`. */
export type ExplainChain = (input: ExplainPromptInput) => Promise<ModelExplanation>;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Fresh per throw, so no two failures share a stack. */
function invalidOutput(): ProviderFailure {
  return new ProviderFailure("invalid_output");
}

const STATUSES = new Set(["success", "unsupported"]);

function isString(value: unknown): value is string {
  return typeof value === "string";
}

/** A nullable card: absent is `null`, present is a record `valid` accepts. */
function isCard(value: unknown, valid: (card: Record<string, unknown>) => boolean): boolean {
  return value === null || (isRecord(value) && valid(value));
}

/**
 * Confirms the parsed JSON really is a {@link ModelExplanation}.
 *
 * Strict mode should make this impossible to fail, which is why it is here: if
 * a provider silently drops the constraint (T18 is measuring exactly that for
 * Gemma), an unchecked cast would let a malformed object reach the response
 * builder. Failing here costs the user nothing, because the slot is released.
 *
 * Deliberately NOT checked: the §33 caps, an empty `explain`, or whether a
 * date is a real date. Those are T12's, which holds the reading to ground
 * against; this is only "is it the shape the schema describes".
 */
export function assertModelExplanation(value: unknown): ModelExplanation {
  if (!isRecord(value)) throw invalidOutput();
  if (!isString(value.status) || !STATUSES.has(value.status)) throw invalidOutput();

  if (!isRecord(value.paper) || !isString(value.paper.title)) throw invalidOutput();

  if (!Array.isArray(value.explain) || !value.explain.every(isString)) throw invalidOutput();

  const todo = value.todo;
  if (!isRecord(todo) || typeof todo.required !== "boolean" || !isString(todo.text)) {
    throw invalidOutput();
  }

  const cardsOk = isCard(
    value.date,
    (c) => isString(c.date) && (c.time === null || isString(c.time)) && isString(c.text),
  ) &&
    isCard(value.caution, (c) => isString(c.text)) &&
    isCard(value.contact, (c) => isString(c.name) && isString(c.phone)) &&
    isCard(value.place, (c) => isString(c.text));
  if (!cardsOk) throw invalidOutput();

  return value as unknown as ModelExplanation;
}

export interface ExplainLegOptions {
  readonly client: ChatClient;
  /** Overrides the client's own model for this leg. */
  readonly model?: string;
  /**
   * Sent only when set, as in `createAnalysisProvider`: it is Groq's reasoning
   * models' setting, and a provider that rejects the field answers 4xx, which
   * is `bad_request` and never falls back.
   */
  readonly reasoningEffort?: Parameters<ChatClient>[0]["reasoningEffort"];
}

/** Builds one schema-constrained explaining leg over a chat client. */
export function createExplainLeg(options: ExplainLegOptions): ExplainLeg {
  const { client, model, reasoningEffort } = options;

  return async (input, signal) => {
    const completion = await client({
      messages: buildExplainMessages(input),
      signal,
      model,
      temperature: 0,
      maxTokens: MAX_OUTPUT_TOKENS,
      responseFormat: EXPLAIN_RESPONSE_FORMAT,
      reasoningEffort,
    });

    let parsed: unknown;
    try {
      parsed = JSON.parse(completion.content);
    } catch {
      // Never attach the raw content: it is an explanation of the user's paper.
      throw invalidOutput();
    }
    return assertModelExplanation(parsed);
  };
}

export interface ExplainChainOptions {
  /** Leg 1: Mistral (`ministral-14b`). */
  readonly mistral: ExplainLegOptions;
  /** Leg 2: Groq (`gpt-oss-120b`). Pass `reasoningEffort`, as the analysis leg does. */
  readonly groq: ExplainLegOptions;
  /**
   * Leg 3: Gemma over the NATIVE client. Optional on purpose (see the header):
   * omit it until T18 has measured that Gemma enforces the schema.
   */
  readonly gemma?: ExplainLegOptions;
  /** The stage's budget. Defaults to {@link DEFAULT_EXPLAIN_STAGE_SECONDS}. */
  readonly totalSeconds?: number;
  /** Per-attempt cap. Defaults to {@link DEFAULT_EXPLAIN_ATTEMPT_CAP_MS}. */
  readonly attemptCapMs?: number;
  /** Fallback floor. Defaults to {@link DEFAULT_EXPLAIN_MIN_FALLBACK_MS}. */
  readonly minFallbackMs?: number;
  /** Correlates the `explain.write` line with the rest of the request. */
  readonly requestId: string;
  /** Defaults to `analysisApiErrorFor`, the mapping this stage needs (T17 pins it). */
  readonly apiErrorFor?: LegChainOptions<ExplainPromptInput, ModelExplanation>["apiErrorFor"];
  /** Milliseconds since epoch. Injected so tests need no clock. */
  readonly now?: () => number;
  /** Injected so tests can see each attempt's budget without a real timer. */
  readonly timeoutSignal?: LegChainOptions<ExplainPromptInput, ModelExplanation>["timeoutSignal"];
  /** Injected so tests can read the event without capturing stdout. */
  readonly log?: LegChainOptions<ExplainPromptInput, ModelExplanation>["log"];
}

/**
 * Builds the explaining chain for one request.
 *
 * Clients and model ids are built by the CALLER from config, so a deploy fault
 * is thrown while the handler is still building its chains, before it reserves
 * a slot (matrix row A8, T15's ordering).
 */
export function createExplainChain(options: ExplainChainOptions): ExplainChain {
  const {
    mistral,
    groq,
    gemma,
    totalSeconds = DEFAULT_EXPLAIN_STAGE_SECONDS,
    attemptCapMs = DEFAULT_EXPLAIN_ATTEMPT_CAP_MS,
    minFallbackMs = DEFAULT_EXPLAIN_MIN_FALLBACK_MS,
    requestId,
    apiErrorFor = analysisApiErrorFor,
    now,
    timeoutSignal,
    log,
  } = options;

  const named: [ProviderName, ExplainLegOptions][] = [["mistral", mistral], ["groq", groq]];
  if (gemma !== undefined) named.push(["gemma", gemma]);

  const legs: ChainLeg<ExplainPromptInput, ModelExplanation>[] = named.map(
    ([name, leg]) => ({ name, run: createExplainLeg(leg) }),
  );

  return createLegChain<ExplainPromptInput, ModelExplanation>({
    legs,
    totalSeconds,
    attemptCapMs,
    minFallbackMs,
    requestId,
    event: EXPLAIN_EVENT,
    apiErrorFor,
    now,
    timeoutSignal,
    log,
  });
}
