# F18 · AI Provider Fallback (Gemini primary, Groq fallback)

- **Branch:** `feature/ai-provider-fallback` (off `develop`) · **Milestone:** post-F17
- **Depends on:** F06 (the `AiAnalysisProvider` seam, the generation schema, the prompt builder — extended, not replaced), F13 (the optional-provider config pattern, the dark-launch `optInFlag`) · **Feeds:** analysis availability and headroom
- **Progress:** 8 / 10 DONE

Adds a second AI analysis provider behind the existing seam and chains the two:
Gemini's free tier serves first, Groq's free tier catches transport failures.
Neither leg ever sees the image — that is unchanged and stays unchanged. The
app is not touched on the analysis path; it has never known which provider
served it, and still won't.

This is also a **privacy-model change**, and the smaller-looking half of the
work is the load-bearing one. Free-tier Gemini permits Google to read the OCR
text; the app currently tells users «ومحدش بيشوفها». T02 fixes the copy before
any Gemini code is wired in.

---

## Context

Three findings, verified 2026-09-26, reframe what this feature is for.

### 1 · The real ceiling is ~66 analyses/day, not 14,400

[Groq's live rate-limit table](https://console.groq.com/docs/rate-limits) for
the model actually deployed, `openai/gpt-oss-120b`:

| | RPM | RPD | TPM | **TPD** |
|---|---|---|---|---|
| Free | 30 | 1,000 | 8,000 | **200,000** |

RPD is not the binding limit — **tokens per day** is. One analysis costs roughly
3,000 tokens (system prompt ~1,200 + OCR text + candidates + ~600 output), so
200,000 TPD allows about **66 analyses**, roughly 22 users at the 3/day product
limit. The 14,400 RPD figure that circulated earlier belongs to other Groq
models, not this one.

The TPM wall was already documented in the code before anyone named it. From
[`analysis-provider.ts`](../../supabase/functions/_shared/ai/analysis-provider.ts) (named `groq-provider.ts` when this was measured, renamed in T01):

> *"`max_tokens` is RESERVED against the per-minute token quota, not merely
> capped — measured on 2026-07-26, the tier allows 8000 tokens/minute … At 4000
> a single analysis claimed over half the minute's budget and three back-to-back
> calls were rate-limited."*

That was the ceiling announcing itself.

### 2 · Free-tier Gemini reads the text — and the text is the document

[Google's Gemini API terms](https://ai.google.dev/gemini-api/terms), Unpaid
Services:

> *"Google uses the content you submit to the Services and any generated
> responses to provide, improve, and develop Google products and services"*
>
> *"human reviewers may read, annotate, and process your API input and output"*

The API input here is the OCR text — the account number, the amount, the name,
the clinic, the court date. **Sending text rather than the image does not
reduce what a reviewer can read; the text is the readable part.** Paid Tier 1
removes this (*"Google doesn't use your prompts … to improve our products"*)
and requires only a linked billing account with no minimum spend, but the
decision for now is to stay on the free tier — knowingly, with the copy
corrected to match.

Groq is the opposite, and better than assumed: [its data policy](https://console.groq.com/docs/your-data)
commits to no training on inputs or outputs on **either** tier, with
account-level Zero Data Retention available. The Groq leg needs no copy change.

### 3 · No stack of free tiers reaches 5,000 users

Gemini's free tier is the same order of magnitude as Groq's. Together they serve
the **low hundreds** of analyses per day. The 5,000-user / ~15,000-per-day
target is three orders of magnitude away — it is not a margin to be tuned by
adding providers. This feature buys **headroom and resilience**, not scale. The
path to that target is a billed Tier 1 project, and `analyze.provider` (T07) is
the instrument that will say when the free ceiling starts to bite.

---

## Locked decisions

1. **Gemini free tier, primary.** No billing account, no card. Accepts the
   data-use terms in Context §2, which T02 makes honest to users.
2. **Groq free tier stays, as the automatic fallback.** Already built, already
   tested, privacy-clean, free. Absorbs Gemini outages and quota exhaustion at
   zero cost.
3. **Gemini is reached over its OpenAI-compatible endpoint**
   (`/v1beta/openai/chat/completions`), which takes the *same* request shape
   Groq already uses — Bearer auth, `messages[]`,
   `response_format: {type:"json_schema", strict:true}`, `temperature`,
   `max_tokens`. One schema, one prompt builder, one parser, two configs.
4. **Failover on transport failures only** — 429, 5xx, network, and a timeout
   that still leaves budget. **Never** on a well-formed 200 whose JSON is
   unusable: that is the model's considered answer about a damaged document,
   `assertModelAnalysis` already catches it, and a second full call would double
   latency for a case the other model will usually fail too.
5. **`GEMINI_MODEL=gemini-3.1-flash-lite`.** `gemini-1.5-flash` is retired
   (404); `gemini-2.5-flash` is [restricted to accounts with prior 2.5 usage](https://ai.google.dev/gemini-api/docs/deprecations),
   which a new project does not have. Env-configured, so changing it is a
   secrets change, not a code change.
6. **Order is chosen by a dark-launched runtime-config flag,**
   `gemini_primary_enabled`, read with the existing `optInFlag` helper. Absent ⇒
   off ⇒ today's behaviour exactly. Reversible from a DB row with no redeploy —
   the same pattern as `azure_ocr_enabled`.
7. **The privacy copy changes before the integration, not after it** (T02). The
   image promise is untouched and remains true; only the text-handling sentence
   moves.
8. **No user-facing text names a provider.** Unchanged from F13-T18 and still
   binding.

**Known risk, gated by T08.** Google documents the OpenAI-compat layer as beta
and says unsupported parameters are *silently ignored* rather than rejected. If
`response_format` were ignored we would get free-form JSON that happens to
parse — the exact failure `ai/analysis-provider.ts` records having already been
observed once with `json_object` mode, where the model invented its own field
names. A live integration test must prove the schema is honoured before the flag
is flipped; `assertModelAnalysis` is the runtime backstop if it ever regresses.

---

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F18-T01 | Provider-neutral seam | Pure rename, zero behaviour change: `groq-output.schema.ts` → `analysis-output.schema.ts`, `groq-client.ts` → `ai/openai-compatible-client.ts` (gains `baseUrl`), `groq-provider.ts` → `ai/analysis-provider.ts` (exports `AiAnalysisProvider`, `assertModelAnalysis`). `deno check` clean, full `deno test` green, diff shows no logic change | **DONE** |
| 2 | F18-T02 | Make the privacy copy true | Every «محدش بيشوفها»-family claim about the **text** audited and listed before editing, then reworded to stop asserting nobody reads it — still accurate that it is not stored and not logged. **Image** promise untouched. No provider named. `CLAUDE.md` §7 updated. Widget tests updated; RTL + Large Text verified | **DONE** |
| 3 | F18-T03 | Groq config module | `ai/groq-config.ts` — `groqOptionsFromEnv()` moved out of the client, now returning `baseUrl`; `isGroqConfigured()`. `GROQ_MODEL` stays deliberately non-defaulted | **DONE** |
| 4 | F18-T04 | Gemini config module | `ai/gemini-config.ts` mirroring `google-config.ts`: `geminiOptionsFromEnv()`, `isGeminiConfigured()`, base URL defaulted but `GEMINI_BASE_URL`-overridable, `GEMINI_MODEL` non-defaulted and fatal-if-key-set-without-it. Unit tests | **DONE** |
| 5 | F18-T05 | The fallback chain | `ai/fallback-provider.ts` + a `providerFault` flag on `ApiError` set only on client error paths. Fails over iff `providerFault` **and** a fallback is configured **and** `totalSeconds - elapsed >= MIN_FALLBACK_SECONDS`. Unit tests cover: 429/5xx/network/timeout-with-budget fail over; timeout-without-budget and malformed-200 do **not**; unconfigured fallback rethrows; fallback's own error surfaces; fallback gets the genuinely remaining seconds; a successful primary never constructs the fallback | **DONE** |
| 6 | F18-T06 | Runtime flag + wiring | `geminiPrimaryEnabled` via `optInFlag` (no migration — absent ⇒ off); `createAnalyser` widened to take it; chain built in `analyze-document/index.ts` with both configs read eagerly so a missing key stays a loud deploy fault that burns no slot | **DONE** |
| 7 | F18-T07 | Observability | `analyze.provider` logs `{request_id, provider, failed_over, primary_error_code}`. Provider names in **server logs** only; §51 content ban unaffected | **DONE** |
| 8 | F18-T08 | Live integration test (risk gate) | `gemini-client.integration.test.ts`, skipped without `GEMINI_API_KEY`: model answers; **`json_schema` + `strict` honoured, not silently ignored**; `ANALYSIS_OUTPUT_SCHEMA` accepted (no 400); bad key → `ANALYSIS_FAILED` not `UNAUTHORIZED`; short timeout aborts. Few, small calls — the free RPD is the budget | **DONE** |
| 9 | F18-T09 | Docs & secrets | `.env.example` gains the `GEMINI_*` block; `supabase/README.md` + project `CLAUDE.md` made provider-neutral; this doc + README row; capacity reality recorded so nobody re-derives the 14,400 figure | TODO |
| 10 | F18-T10 | Quality comparison before the flip | Both providers over the golden-set folder, comparing `document_type`/`amounts`/`dates`/`status` per document. Gemini 3.1 Flash-Lite must match or beat `gpt-oss-120b` on Egyptian paperwork before the flag is set; otherwise `GEMINI_MODEL` moves to `gemini-3.5-flash-lite` and the comparison repeats — no code change. Paced against the free RPM | TODO |

---

## T02 · Privacy-copy audit (2026-09-26)

Every «محدش بيشوفها»-family claim, found by grepping `lib/` and `test/` for the
claim family and for every privacy-adjacent string, **before** any edit. Four
occurrences are in scope; two adjacent findings are recorded but deliberately
left alone.

### In scope

| # | Location | Current text | Why it must change |
|---|---|---|---|
| 1 | `lib/core/localization/ar_strings.dart:112` · `privacyPointTextOnly` | «بنقرا الكلام اللي في ورقتك بمعالجة آمنة، لكن مانحفظش صورتها أبدًا — ومحدش بيشوفها.» | The only literal «محدش بيشوفها». It opens on the **text**, switches to the **image**, then ends with an unattached "and nobody sees it" that a reader takes as covering both. False for the text on a free-tier leg. |
| 2 | `lib/core/localization/en_strings.dart:112` · `privacyPointTextOnly` | "We read your paper using secure processing, but we never save the photo — no person ever sees it." | Same conflation, and *more* explicit than the Arabic: "no person ever sees it" is exactly what free-tier terms permit. |
| 3 | `CLAUDE.md:17` · Project Context → Privacy (non-negotiable) | «بنقرا نص الورقة بمعالجة آمنة، لكن **صورتها نفسها متتحفظش خالص ومحدش بيشوفها**» | Here «محدش بيشوفها» *is* attached to الصورة and stays true, but the sentence leads with the text claim, so the text/image split has to be made explicit or the next reader re-conflates it. |
| 4 | `CLAUDE.md:82` · §7 hard rules | الصياغة المعتمدة: «بنقرا النص بمعالجة آمنة، لكن مانحفظش الصورة، ومحدش بيشوفها» | **The load-bearing one.** This is the *mandated* wording for all user-facing copy. Leave it and every future screen re-introduces the false claim. |

Rendering surfaces, for completeness: both occurrences of (1)/(2) reach users
through a single widget, `core/widgets/privacy_policy_content.dart`, shared by
the first-run `PrivacyScreen` and Settings → «سياسة الخصوصية». Both hosts wrap
it in a `SingleChildScrollView`, so longer copy cannot overflow at Large Text.

No test hardcodes the Arabic or English literal — every assertion goes through
the getter (`ar.privacyPointTextOnly`), so the four widget tests follow the new
wording automatically and needed no edit. Verified by grepping `test/` for the
literals: zero hits.

### Adjacent, out of scope — flagged, not fixed

| # | Location | Text | Finding |
|---|---|---|---|
| 5 | `ar_strings.dart:499` / `en_strings.dart` · `settingsProcessingModeTextOnlyDescription` | «بس يطلع النص من الورقة من غير تحليل — كل حاجة تفضل على الموبايل» | "Everything stays on the phone" is false for two reasons, both predating F18: with `azureOcrEnabled` the **image** leaves for OCR, and — see (6) — the mode never reaches the pipeline at all. |
| 6 | `lib/core/analysis/processing_mode.dart:13` | "OCR only — no text leaves the phone, no network call." | `GetProcessingMode` is injected into `SettingsCubit` **and nowhere else**: the analysis flow never reads it, so choosing «استخراج النص فقط» changes no behaviour. The setting is inert, which makes its description a promise nothing keeps. An F11-T03 gap, not an F18 one — it needs the mode wired into the flow, not a copy change, and it must not be papered over by rewording. |

## T08 · Risk-gate result — decision 3 holds (verified live 2026-09-26)

The bet in locked decision 3 — that Gemini's OpenAI-compatible endpoint takes
the same request shape, schema and prompt as Groq — was tested against the live
API with a real key and **passed on all five checks**:

| Check | Result |
|---|---|
| `gemini-3.1-flash-lite` answers at all | ✅ not retired, not access-restricted |
| `ANALYSIS_OUTPUT_SCHEMA` accepted | ✅ HTTP 200, no `additionalProperties` or nullable-type rejection |
| `json_schema` + `strict` **honoured, not silently ignored** | ✅ returned keys exactly equal the schema's `required` set; enums respected |
| A bad key → `ANALYSIS_FAILED`, never `UNAUTHORIZED` | ✅ and marked `providerFault`, so the chain fails over |
| An impossibly short timeout aborts | ✅ no hang |

**Consequence:** the native Gemini endpoint is not needed, the client module
stays as it is, and one transport genuinely serves both legs. The documented
beta-layer risk (unsupported parameters *silently ignored*) did not materialise
for `response_format`. `assertModelAnalysis` remains the runtime backstop if it
ever regresses.

### Two things the live run also settled

1. **Groq's TPM ceiling is real and easy to hit.** Running the full suite with
   both keys fails four Groq analysis tests with `AI_RATE_LIMITED` — not a
   defect, but the 8,000 TPM wall: each analysis reserves `max_tokens: 2000`, so
   roughly four fit in a minute and the suite runs about seven back-to-back.
   This is the capacity problem F18 exists to mitigate, observed directly. Live
   Groq analysis tests must be **paced**, which T10 already requires.
2. **Two Groq integration tests had never actually run green.** They set
   `max_tokens` to 10 and 50, but `openai/gpt-oss-*` charges its reasoning trace
   against `max_tokens` before writing any answer — so one returned an empty
   completion (`finish_reason: "length"`) and the other an outright HTTP 400
   `json_validate_failed` on the empty generation. They self-skip without a key
   and CI has none, so the breakage was invisible. Fixed in T08 by passing
   `reasoningEffort: "low"` and a realistic budget, matching what
   `ai/analysis-provider.ts` sends in production and documents at length.

## Provider selection matrix

Keys-absent is bit-for-bit today's behaviour, which is what makes the rollout safe.

| `gemini_primary_enabled` | `GEMINI_API_KEY` | Primary | Fallback |
|---|---|---|---|
| absent / false | absent | Groq | none — *identical to today* |
| absent / false | set | Groq | Gemini — *Groq's ~66/day goes first, Gemini takes the overflow* |
| true | set | **Gemini** | Groq |
| true | absent | Groq | none — *config error; logged loudly* |

## Time budget

The chain must fit **inside** the existing `aiTimeoutSeconds` (25s), so the
slot-TTL arithmetic in `analyze-handler.ts`
(`aiTimeoutSeconds + RESERVATION_GRACE_SECONDS`) stays correct and no user waits
longer than today. There is no client-side timeout in Dart — the Edge Function's
budget is the only gate.

- Primary gets `PRIMARY_SHARE` (0.6) → 15s of 25s.
- Fallback gets what **actually** remains, measured from elapsed time. A primary
  that 429s in 200ms leaves the fallback ~24.8s — the common case on a free tier.
- `MIN_FALLBACK_SECONDS` (8): below that, no failover; the primary's error is
  returned. A timeout that consumed the budget therefore cannot trigger a second
  doomed call.

## Rollout

1. Merge with the flag absent — production byte-for-byte unchanged.
2. Ship T02's copy change to users **before** the flag is flipped.
3. Create a Gemini API key in Google AI Studio. No billing account, no card.
4. `supabase secrets set --env-file supabase/.env` with `GEMINI_API_KEY` and `GEMINI_MODEL`.
5. Run T08 against the live key. **Stop if the schema gate fails** — decision 3
   would be invalid and the native Gemini endpoint becomes necessary; only the
   client module changes.
6. Run T10. Stop if quality regresses.
7. `insert into public.app_runtime_config (key, value) values ('gemini_primary_enabled','true'::jsonb) on conflict (key) do update set value = excluded.value;`
8. Watch `analyze.provider` for failover rate and `analyze.completed` for status
   mix. Rollback is setting that row to `false` — no deploy.

## Exit DoD

Both legs wired behind one seam, chained, and proven by unit tests that need no
network plus one live gate that proves the schema is honoured. Privacy copy
accurate against the free-tier terms, image promise unchanged, no provider named
to a user. Flag absent ⇒ today's behaviour, test-enforced. Zero changes to the
Flutter analysis path. `dart format .` / `flutter analyze` / `flutter test` and
`deno check` / `deno test` all pass.

## Out of scope

- Load balancing or quota-aware routing. The chain is resilience and overflow,
  not scheduling.
- Prompt or schema tuning for Gemini. Both legs share one prompt and one schema
  deliberately; if Gemini needs different prompting that is a separate feature
  and a separate measurement.
- Paid tiers on either provider, and therefore the 5,000-user target.
