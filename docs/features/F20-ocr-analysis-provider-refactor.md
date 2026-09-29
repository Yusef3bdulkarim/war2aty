# F20 · OCR & Analysis Provider Refactor (Gemini OCR, Mistral analysis)

- **Branch:** `feature/ocr-analysis-providers` (off `develop`) · **Milestone:** post-F19
- **Depends on:**
  - F13: the online route, the `ocr-document` endpoint split in F14, and the `optInFlag` dark-launch pattern.
  - F18: the `_shared/ai/*` seam, the OpenAI-compatible client, the fallback chain and the `analyze.provider` observability line. F20 **modifies** these; it does not rebuild them.
- **Supersedes:** F18. It is cancelled, and its Gemini-as-classifier wiring is removed. Parts of F13 are superseded too: Azure and Google Document AI are removed, and locked decision #2 is reversed.
- **Progress:** 14 / 27 DONE (T01, T03–T15). T02 waived by the owner (2026-09-29): drafts accepted uncorrected. T09 signed off on partial evidence (see its row)
- **Plan of record:** approved 2026-09-28 (rev 3). The gate protocol is at the bottom.

Azure AI Document Intelligence is a paid service, and War2aty never moves to a
paid tier for any upstream service. F20 replaces it, and Google Document AI with it,
with two **independent** layers that each run entirely on free tiers:

| Layer | Primary | Fallback | Where the fallback is decided |
|---|---|---|---|
| **1 · OCR** (image → text) | Gemini, server-side in `ocr-document` (`GEMINI_MODEL`) | Tesseract, **on the device** | Flutter, in `OcrReviewCubit`. The fallback is **always visible**: the user sees a warning banner and it is never silent |
| **2 · Analysis** (text → JSON) | Mistral (`MISTRAL_MODEL`) | Groq (`GROQ_MODEL`, `openai/gpt-oss-120b`) | Server, in `analyze-document` |

Together AI and OpenRouter were both evaluated and rejected. Together AI's
"free tier" is only a one-time signup credit. Neither appears anywhere in the code.

---

## Context

### 1 · The image-analysis path has been dead since F14

Since F14, every analysis goes through the **text** request shape of
`analyze-document`. The online route calls `ocr-document`, the user reviews the
text on the device, and only then does the app send `input_type:"text"`. The
following pieces are therefore unreachable, and T15/T19 delete them:

- the image shape of `analyze-document`;
- the Azure word-confidence verification layer (`field-verification.ts`,
  `cross-provider-validator.ts`);
- Flutter's `analyzeImage` chain.

Gemini returns no per-word confidences, so there is nothing to port. Deleting
them changes no current behaviour.

### 2 · Mistral Saba is retired

The original request named Mistral Saba for its Arabic strength, with Mistral
Small as an internal fallback. Saba was retired on 2025-09-30, and Mistral's own
docs point new integrations to Mistral Small. The internal Saba → Small chain
therefore collapses to `MISTRAL_MODEL=mistral-small-latest`, and Groq is the
fallback. The model is env-configured so that it can change without a redeploy.

### 3 · Privacy changes, knowingly

The owner accepted that document **images** go to Gemini's free tier, whose
terms allow Google to review API input. F18-T02 already stopped the app from
claiming that nobody reads the **text**. F20 (T24) extends the same honesty to
the **image**. No user-facing string names a provider.

### 4 · F17 stays on its own branch

F17 (`feature/ocr-accuracy`) is not finished and is **not** merged into `develop`
(owner decision, 2026-09-28). F20 takes two things from it without merging it:

- **The Arabic-Indic digit fold** (`8576134`): every extractor matches `\d`,
  which never matches `٠-٩`. T13 applies `normaliseDigits` to Gemini's text
  before the extractors run, and ports that commit's regression test. The Azure
  pipeline that `8576134` patched is deleted here, so the commit itself is not
  cherry-picked.
- **The benchmark harness** (`supabase/tools/ocr-benchmark.ts`): T08 ports it and
  makes it provider-agnostic.

---

## §1 · Failure matrix

This matrix is the source of truth. T27 must show a test for **every row**.

**Independence rules**
- The OCR fallback is decided only on the client, and only from the OCR call's
  own failure.
- The analysis fallback is decided only on the server, and only from the
  analysis provider's failure.
- An analysis failure never triggers a new OCR, and an OCR fallback never
  changes the analysis chain. Tesseract text goes through the same
  Mistral → Groq chain.
- OCR never consumes a quota slot, including when it falls back to Tesseract.
  An analysis consumes exactly one slot, however many providers it tries.

### Layer 1 · OCR (`ocr-document` → `OcrReviewCubit`)

| # | Condition | Server answer | Client `AppFailure` | Tesseract fallback? |
|---|---|---|---|---|
| O1 | Gemini returns text | 200 | — | No, success |
| O2 | Gemini returns an empty transcription | 200, `ocr_text:""` | → `OcrReviewPoorQuality` | **No** |
| O3 | Gemini answers 429 | 429 `AI_RATE_LIMITED` | `AiProviderRateLimitFailure` | **Yes** |
| O4 | Gemini runs past the deadline | 408 `TIMEOUT` | `RequestTimeoutFailure` | **Yes** |
| O5 | Gemini 5xx, network error, malformed body, `blockReason`, or `finishReason` of SAFETY / RECITATION / OTHER | 502 **`OCR_UNAVAILABLE`** (new) | `OnlineOcrUnavailableFailure` (new) | **Yes** |
| O6 | Gemini 400 / 401 / 403 / 404, or `GEMINI_*` env missing | 500 `INTERNAL_ERROR` | `AnalysisServiceFailure` | **No**: config or programmer fault |
| O7 | Device offline, connection dropped, or client receive timeout | — | `NoInternetFailure` / `RequestTimeoutFailure` | **Yes** |
| O8 | Consent declined | Request never sent | `AnalysisConsentDeclinedFailure` | **No** |
| O9 | Session invalid | 401 `UNAUTHORIZED` | `UnauthorizedFailure` | **No** |
| O10 | `online_ocr_enabled` switched off after the route was chosen | 502 `OCR_UNAVAILABLE` (was `INVALID_REQUEST`) | `OnlineOcrUnavailableFailure` | **Yes** |
| O11 | Gateway 5xx without our error envelope | Non-envelope 5xx | `AnalysisServiceFailure` | **No**: deploy fault |
| O12 | Kill switch, app below minimum version, or oversized / malformed body | 503 / 400 / 400 | `AnalysisDisabledFailure` / `UnsupportedAppVersionFailure` / `InvalidRequestFailure` | **No** |
| O13 | Our own response contract broken (`schema_version` or body) | 200 | `InvalidAnalysisResponseFailure` | **No**: programmer error |
| O14 | Tesseract itself fails during the fallback | — | The **original** online failure | Error page |
| O15 | Tesseract returns empty text during the fallback | — | → `OcrReviewPoorQuality` | — |
| O16 | Request went stale (Retake, Back, close, or a newer `runOcr`) | Any | — | Result discarded, no emit, Tesseract never starts |

**The client allowlist is closed:** `AiProviderRateLimitFailure`,
`RequestTimeoutFailure`, `OnlineOcrUnavailableFailure` and `NoInternetFailure`.
Any other failure does not fall back.

### Layer 2 · Analysis (`analyze-document`)

Provider clients throw an internal `ProviderFailure{kind}`, which replaces F18's
`providerFault` boolean. The chain decides from `kind` alone. Nothing changes on
the wire for the app.

| # | `kind` | Source | Groq fallback? | Wire answer when final |
|---|---|---|---|---|
| A1 | `rate_limited` | HTTP 429 | **Yes** | 429 `AI_RATE_LIMITED` |
| A2 | `upstream_unavailable` | HTTP 5xx / 529, or 408 (the provider's own timeout) | **Yes** | 500 `ANALYSIS_FAILED` |
| A3 | `timeout` | Attempt aborted by its budget (§2) | **Yes**, if `remaining ≥ MIN_FALLBACK_MS` | 408 `TIMEOUT` |
| A4 | `network` | Non-timeout fetch failure | **Yes** | 500 `ANALYSIS_FAILED` |
| A5 | `invalid_output` | Empty content, `finish_reason:"length"`, non-JSON, `assertModelAnalysis` failure, or **semantic validation** failure (§3) | **Yes** | 500 `ANALYSIS_FAILED` |
| A6 | `auth` | HTTP 401 / 403 | **No** | 500 `INTERNAL_ERROR` |
| A7 | `bad_request` | HTTP 400 / 404 / 422 | **No** | 500 `INTERNAL_ERROR` |
| A8 | config | `MISTRAL_*` or `GROQ_*` missing (both required, fail fast before a slot is reserved) | **No** | 500 `INTERNAL_ERROR` |
| A9 | programmer | Anything thrown that is not a `ProviderFailure` | **No**, rethrown | 500 `INTERNAL_ERROR` |
| A10 | Both providers fail | — | — | The last attempt's mapping; the slot is released |

Classification is done per client. For example, Groq's HTTP 400
`json_validate_failed` is a model-output failure (`invalid_output`). Only the
status and Groq's `error.code` string are read, and the body is never logged.

## §2 · Timeout contract

This replaces F18's 60/40 `PRIMARY_SHARE`.

- **One overall deadline per request**, `aiTimeoutSeconds` (25 s). The client's
  `receiveTimeout` of 40 s stays above it.
- **Each attempt gets whatever time remains:**
  `min(deadline.remaining(), AI_ATTEMPT_TIMEOUT_SECONDS)`. The cap only stops a
  hung primary from starving the fallback, and its value is set from the T09 p95.
- **The fallback runs only if `remaining ≥ MIN_FALLBACK_MS`.** Otherwise the
  request answers `TIMEOUT`.
- **`ocr-document`** makes a single Gemini attempt with the whole deadline.
  On-device Tesseract has no deadline, the same as the offline route today.

## §3 · Semantic validation

**Hard rejects** raise `invalid_output`, which is fallback-eligible. They live in
`_shared/analysis/semantic-validation.ts` and run inside each attempt:

- **S1:** when `status` is success or partial, `summary.short`,
  `summary.detailed` and `document_type.title` must not be blank.
- **S2:** those fields, and the text of `actions_required` and `instructions`,
  must be mostly Arabic script. The threshold is tuned on the corpus.
- **S3:** strings and arrays must stay within length bounds.
- **S4:** `summary.detailed` must not be a verbatim echo of the OCR input.

**Soft checks** stay as F06-T12's `validateAnalysis`, unchanged: it downgrades
fields and never rejects. **Gate G5:** the hard rules reject nothing the owner
judged acceptable.

## §4 · Stale-request protection (`OcrReviewCubit`)

- `runOcr()` takes a generation token. Every `await` is followed by
  `if (isClosed || gen != _generation) return;`.
- `cancelPending()` bumps the token. It is called from `cleanupImage()`,
  `close()`, and the Retake / Pick-another / Back handlers.
- The fallback never starts on a stale token. A stale Tesseract result is
  discarded.

---

## Decisions (resolved 2026-09-28)

| # | Decision | Resolution |
|---|---|---|
| D1 | Gemini key and model | The owner has a key. `GEMINI_MODEL` is required, with no default. **T09: `gemini-3.5-flash-lite`.** On this key `gemini-2.5-flash` answers 404, and the 3.x Flash models answer 503 about half the time on the free tier (`gemini-3.8-flash` failed 3/6) |
| D2 | Mistral model | ~~`mistral-small-latest`~~ **Revised in T09: `ministral-14b-latest`.** The free plan gives `mistral-small-*`, `mistral-medium-*` and `magistral-*` a limit of 0 requests/min (every call 429s); only the Ministral family is usable (14b: 30 RPM). No chain inside Mistral. Opt out of training in the Mistral console |
| D3 | Delete the dead image-analysis path | Yes, on the server and in Flutter |
| D4 | Groq fallback model | Keep `openai/gpt-oss-120b` |
| D5 | Failure matrix, including O10 / O11 / A3 | Approved as above |
| D6 | Fallback-banner and privacy copy | Approved as in T23 / T24 |
| D7 | F17 | **Not merged**, because F17 is unfinished. The digit fold is applied in T13 and the benchmark is ported in T08 |
| D8 | Corpus exposure to free tiers | Accepted by the owner |

---

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F20-T01 | Branch & bookkeeping | Branch `feature/ocr-analysis-providers` off `develop`; this task file; memory updated (F18 cancelled, Saba retired, F13 decision #2 reversed); corpus already git-ignored on `develop` (`486382e`) — verified | **DONE** |
| 2 | F20-T02 | Corpus assembly | `golden/` has ≥ 3 documents in each of C1 printed Arabic, C2 mixed Ar/En, C3 invoices/receipts, C4 utility bills, C5 official/government, C6 date-heavy, C7 dense/small text, C8 poor quality, C9 perspective/skew/folds. C10 handwritten is regression-only. Target ≥ 36 documents, covering both digit systems. Truth schema v2 adds `languages[]`, `expected_document_type`, and key `dates` / `amounts` / `actions`. Drafts are bootstrapped from **Tesseract** (not Gemini, to avoid bias) and every file is owner-corrected | **WAIVED** — 2026-09-29: 59 truth files exist. 6 are owner-corrected (F17, schema v1); the rest are uncorrected Tesseract drafts. The owner reviewed a sample (two wholly wrong, the rest ~60–85 % right) and waived correction. Uncorrected drafts are never scored (`UNCATEGORISED`), so every T09 number comes from the 6 corrected files |
| 3 | F20-T03 | Failure taxonomy & deadline | `_shared/ai/provider-failure.ts` (kept next to the existing F18 transport, not a new `providers/` folder): `ProviderFailure{kind}`, `PROVIDER_FAILURE_KINDS`, `isFallbackEligible`, `providerFailureForStatus`, `analysisApiErrorFor`. `_shared/time/deadline.ts`. Only adds modules, so no behaviour changes. `ApiError.providerFault` is removed in T04 (transport) and T10 (chain). 52 tests; full suite 673/673 | **DONE** |
| 4 | F20-T04 | Remove the F18 classifier wiring | Deleted: `resolveProviderOrder`, the `gemini_primary_enabled` / `geminiPrimaryEnabled` flag, the Gemini analysis leg, `ApiError.providerFault` / `asProviderFault`, and `gemini-client.integration.test.ts`. `openai-compatible-client.ts` takes a per-call `signal` and throws `ProviderFailure` per §1, adding `finish_reason:"length"` and Groq's 400 `json_validate_failed` → `invalid_output`. New `AnalysisLeg` (throws `ProviderFailure`); `AiAnalysisProvider` stays endpoint-facing (throws `ApiError`). The parser's failures are now `invalid_output`, which is fallback-eligible (A5, reversing F18 decision 4). The chain has interim changes (allowlist + `analysisApiErrorFor` mapping); the F18 time split stays until T10. Groq runs alone until T11. **Wire note:** a Groq 401/403/404/other-400 now answers `INTERNAL_ERROR` instead of `ANALYSIS_FAILED` (A6/A7). Both are HTTP 500 and reach the app as the same `AnalysisServiceFailure`, so users see no change. `gemini-config.ts` and `compare-providers.ts` are kept, and adapted to compile, for T07 / T08. 658/658 | **DONE** |
| 5 | F20-T05 | Semantic validation | `_shared/analysis/semantic-validation.ts` covers S1–S4, with a pass and a fail test for each rule. `semanticViolations(analysis, ocrText)` returns the broken rules (for T08); `assertSemanticallyValid` throws `ProviderFailure("invalid_output")`. S1 exempts `unsupported`. S2 is measured on letters across the reader-facing text together (title, summaries, actions, instructions), so a Latin brand name in a title passes. S3 bounds a runaway answer and does not re-impose §30's 200-char `summary.short` cap, which the response builder already shortens. S4 compares letters and digits only, both ways (a copied stretch, or the page pasted inside), from 60 chars up. `SEMANTIC_LIMITS` are provisional and get tuned in T09 (G5). Only adds a module: T06 wires it into the leg after `assertModelAnalysis`. 27 tests; full suite 685/685 | **DONE** |
| 6 | F20-T06 | Mistral leg | `ai/mistral-config.ts`: `MISTRAL_API_KEY` and `MISTRAL_MODEL` required, trimmed, not defaulted; base URL `https://api.mistral.ai/v1`. Reuses the OpenAI-compatible client; sends no `reasoning_effort`; strict `json_schema`, `temperature 0`, `max_tokens 2000`. The provider runs `assertModelAnalysis` and then semantic validation. Tests. `reasoning_effort` is now a per-leg option with no default: `GROQ_REASONING_EFFORT` (`"low"`) moved to `groq-config.ts`, and every Groq call site passes it, so Groq's request is unchanged. Semantic validation runs in `createAnalysisProvider`, so every leg gets it. **Behaviour note:** until T11, Groq runs alone, so an answer failing S2–S4 now answers `ANALYSIS_FAILED` (slot released) instead of reaching the user. Mistral accepting the schema's nullable `type: ["string","null"]` under strict mode is proven live in T09. 705/705 | **DONE** |
| 7 | F20-T07 | Gemini OCR client | `ai/gemini-ocr-client.ts` over `gemini-config.ts`: native `generateContent`, `x-goog-api-key`, image sent as `inline_data`, a fixed verbatim-transcription prompt, `temperature 0`, bounded `maxOutputTokens`. Classified per O3–O6. Tests for every branch. `gemini-config.ts` now serves the native API only (`GEMINI_BASE_URL` `…/v1beta`); its OpenAI-compat options, base-URL override, `DEFAULT_GEMINI_MODEL` and `isGeminiConfigured` are gone. `maxOutputTokens` 8192. Only `finishReason: STOP` is accepted, so `MAX_TOKENS` (a page cut off mid-way) is `invalid_output` too, and so is any reason Google adds later. `thought` parts are skipped. A timeout while the body streams is still `timeout`. `compare-providers.ts` now compares Mistral with Groq (its Gemini leg needed the removed compat options). The `.env.example` Gemini block is rewritten and `GEMINI_MODEL` is left empty until T09. Not wired until T13. 738/738 | **DONE** |
| 8 | F20-T08 | Benchmarks | F17's `ocr-benchmark.ts` ported to `--ocr gemini|tesseract`, with Tesseract run through the CLI and the app's `assets/tessdata` (a documented approximation). Azure numbers come from the recorded `baseline.json`, and Azure is never called. `analysis-benchmark.ts --analyser mistral|groq`, built on `compare-providers.ts`, runs over truth, Gemini and Tesseract text. Only metrics go to stdout; runs are paced to free-tier limits. Shared modules in `tools/benchmark/`: `metrics` (CER/WER, per-script CER, digit accuracy, critical recall/precision with OCR-vs-extractor loss, P/R, p50/p95), `truth` (schema v2 for T02; F17's v1 files still load, with the analysis-only metrics shown as "—"), `corpus` (I/O, digit-folded `candidatesFor`, 429 backoff), `gates` (G1–G5 printed per run; unmeasurable gates show `?`, never PASS), `legs` (production legs + a recording fetch that separates `length` / schema / semantic failures with no production change). `--bootstrap` drafts v2 truth from Tesseract only. Transcriptions go to `golden-ocr/`, answers to `golden-analysis/`, and owner ratings to `golden-analysis/ratings.json` (G5); all are git-ignored. `compare-providers.ts` uses the shared legs. When T13 lands, the OCR benchmark should drive the real pipeline instead of `candidatesFor`. Not run live: Tesseract is not installed on the dev machine. 795/795 | **DONE** |
| 9 | F20-T09 | Run, record, **GATE** | OCR (CER/WER overall and per script, digit accuracy, critical-field recall/precision, extractor loss vs OCR loss, error rate, latency) and analysis (schema/semantic-valid rate, type accuracy, date/amount P/R, Arabic-summary rate, `length` finishes, tokens, latency, owner rating) are recorded per document, per category and overall. **Gates:** G1 Gemini CER ≤ Azure baseline (0.273) and ≤ 0.10 on C1–C7; G2 critical recall ≥ 0.9 on C1–C7; G3 Gemini p95 ≤ 15 s; G4 Mistral 100 % schema-valid, ≥ 97 % semantic-valid, and within 5 pp of Groq; G5 zero semantic false rejects; G6 Tesseract recorded as the floor. The p95 sets `AI_ATTEMPT_TIMEOUT_SECONDS` and `MIN_FALLBACK_MS`. **Owner sign-off is required** | **DONE — owner sign-off 2026-09-29 on partial evidence.** Measured on the 6 corrected F17 docs only (the same set as the Azure baseline). **OCR** CER: Azure 27.3 %, Gemini 3.5 Flash-Lite 29.3 % (printed 0 %, handwritten forms 32.4 %, prose 78.8 %; p95 5.5 s; 0/6 failed), Tesseract 67.4 % (G6 floor). **Analysis** (truth text / Gemini text): Ministral 14B 6/6 schema- and semantic-valid on both, 100 % Arabic summaries, 0 `length`, p95 12.2 s / 12.7 s; Groq 6/6 on both, p95 3.1 s / 2.5 s, plus one intermittent `json_validate_failed` in 12 calls. **Gates:** G1a FAIL (29.3 % vs 27.3 %, by 2 points); G1b, G2 unmeasured (no C1–C7 docs); G3 PASS; G4a/b PASS; G4c PASS but weak (only the semantic-valid rate is comparable on v1 truth); G5 PASS vacuously (nothing rejected, nothing rated); G6 recorded. `SEMANTIC_LIMITS` stay provisional. **Timing set from the p95:** `AI_ATTEMPT_TIMEOUT_SECONDS=18` (Mistral's slowest was 14.7 s; leaves 7 s of the 25 s budget for Groq) and `MIN_FALLBACK_MS=5000` (Groq p95 3.1 s). The owner accepted G1a's failure and the unmeasured gates and lifted the hard stop |
| 10 | F20-T10 | Fallback chain | `ai/fallback-provider.ts` rewritten per §1 A1–A10 and §2. `ProviderName` is `mistral` or `groq`. The existing `analyze.provider` line carries `kind`. Tests for every row and deadline edge. One `Deadline` per analysis, started at the call (not at chain construction). Each attempt gets `deadline.signal(attemptCapMs)`; the fallback starts only with `remainingMs() ≥ minFallbackMs`. `DEFAULT_ATTEMPT_CAP_MS` 18 000 and `DEFAULT_MIN_FALLBACK_MS` 5 000 (from T09) are option defaults; T11 reads them from the environment. Legs are plain `AnalysisLeg`s: `BudgetedLeg`, `PRIMARY_SHARE` and `MIN_FALLBACK_SECONDS` are gone. The kind rides in the existing `primary_failure` / `failure` fields. A8 never reaches the chain (T11's handler tests cover it). **Behaviour note:** until T11 Groq runs alone, and its per-call budget moves from F18's 15 s share to the 18 s cap, still inside the 25 s deadline. 800/800 | **DONE** |
| 11 | F20-T11 | Wire `analyze-document` | Mistral → Groq with both required. `.env.example` gains `MISTRAL_*`, `AI_ATTEMPT_TIMEOUT_SECONDS` and `MIN_FALLBACK_MS`. Handler tests prove one slot per analysis with or without fallback, and that the slot is released when both providers fail. `_shared/ai/chain-timing.ts`: `chainTimingFromEnv()` reads both knobs (optional; unset or blank → the T09 defaults; set but not a positive number → throws naming the variable, before any slot, A8). `analyze-document` builds Mistral (no `reasoning_effort`) → Groq (`GROQ_REASONING_EFFORT`) and reads every credential before reserving. Handler tests drive the real chain over fake legs: Mistral served (Groq never called), Groq served after a Mistral 429 (one reserve, one successful finalize), both failed (released, `ANALYSIS_FAILED`), bad Mistral key (released, Groq never called), missing credential (500, no reservation). `.env.example` documents `ministral-14b-latest`, `gemini-3.5-flash-lite`, the Mistral training opt-out (D2) and the two knobs. **Deploy note:** the remote project needs `MISTRAL_API_KEY` and `MISTRAL_MODEL` set before this ships, or every analysis answers `INTERNAL_ERROR`. 816/816 | **DONE** |
| 12 | F20-T12 | `OCR_UNAVAILABLE` code | Added to `error-codes.ts` (502) and to `API_CONTRACT.md` §31 | `ApiError.ocrUnavailable()`, whose machine message names no provider. §31 gains the table row, the schema enum value, the error schema now describing `ocr-document` too, and client rule 7 (the four failures that fall back to on-device reading). Nothing emits it until T13; an app built before T18 maps it to `AnalysisServiceFailure` under rule 3, so shipped clients are unaffected. 817/817 | **DONE** |
| 13 | F20-T13 | Gemini OCR pipeline | `createImageOcrPipeline({geminiClient})` runs Gemini, then `normaliseDigits`, then `runExtractors`, and returns `{ocrText, candidates}`. `ocr-handler.ts` and `ocr-document/index.ts` rewired. Flag off → `OCR_UNAVAILABLE`. `8576134`'s digit-fold regression test ported | `_shared/analyze/image-ocr-pipeline.ts` exports `readingFromText` (fold, then extract), which the benchmark's `candidatesFor` now calls, so the benchmark scores the shipped step and not a copy. `runExtractors` moved to `_shared/extractors/run-extractors.ts` (the Azure pipeline uses it until T15). `ocrApiErrorFor` in `provider-failure.ts`: rate limit → 429, timeout → 408, outage / network / unusable → 502 `OCR_UNAVAILABLE`, auth / bad request → 500 `INTERNAL_ERROR`. The handler makes one Gemini attempt with the whole `aiTimeoutSeconds`, builds the client per request (missing `GEMINI_*` → 500, O6), logs `ocr.failed` with kind and code only, and answers `OCR_UNAVAILABLE` when the flag (still `azureOcrEnabled` until T14) is off. `ocr-document` no longer imports Azure or Google. F17's three digit-fold tests are ported; its word-offset test has no counterpart (Gemini returns no offsets). **Live:** the OCR benchmark through the new step read 6/6 (CER 28.3 %, p95 2.3 s, 0 extractor loss); with the retired `gemini-1.5-flash` every call answered `bad_request`, i.e. O6, no fallback. 843/843 | **DONE** |
| 14 | F20-T14 | Neutral OCR flag | Migration: `online_ocr_enabled=false`, and `azure_ocr_enabled` removed. `RuntimeConfig.onlineOcrEnabled` uses `optInFlag`. The usage wire field is `online_ocr_enabled`. Tests | Migration `20260929120000_online_ocr_flag.sql` seeds `online_ocr_enabled=false` whatever `azure_ocr_enabled` said (that approved Azure, not Gemini) and deletes the old row; its header carries the owner's switch-on statement for after T27. Server renamed throughout (`RuntimeConfig`, `ocr-handler`, the dead image gate in `analyze-handler` until T15, `get-usage`). New tests: a leftover `azure_ocr_enabled=true` row never enables online reading; the old field is absent from `get-usage`. `API_CONTRACT.md` §32 lists `online_ocr_enabled`. **Transition:** until T17 the app reads the missing `azure_ocr_enabled` as `false` and stays on the on-device route, the safe direction. **Not applied live:** Docker was not running; T27 applies it on the local stack. 845/845 | **DONE** |
| 15 | F20-T15 | Delete the dead image path (server) | Image parser, handler branch, `createImagePipeline`, the `verification` plumbing in prompt / response / validation, and `_shared/verification/*` with its tests. `schemaVersion` stays `"2.0"` | Deleted: `image-analysis-pipeline.ts`, `_shared/verification/{field-verification,cross-provider-validator}.ts` and their three test files, the handler's `input_type` dispatch, `readImage` and `createImagePipeline`. `analyze-document` is text only; an image body is `INVALID_REQUEST` via the text parser, even with online reading on, and takes no slot. `verification` is gone from the prompt input, the response builder and the validation pipeline (on the text path it was always `null`, so validation and the user message are unchanged apart from one blank line). **Deviation:** the image PARSER stays, because it is `ocr-document`'s request body; only its comments changed. **System prompt:** rule 15 (the `## Verification` note) removed and rule 16 renumbered to 15, so every request's system prompt is slightly shorter; a test pins gap-free numbering. `phones`/`references` stay on the v2 wire, always empty (as the text path always sent them). `AMOUNT_KEYWORDS` / `REFERENCE_KEYWORDS` lost their T06-only `export`. `API_CONTRACT.md` §29b now describes `ocr-document`'s body, the `OCR_UNAVAILABLE` gate and Gemini's free-tier terms; the full docs pass stays T26. 798/798 | **DONE** |
| 16 | F20-T16 | Delete Azure & Google | `_shared/azure/*`, `_shared/google/*`, their tests, and their `.env.example` / `config.toml` entries. A grep for `azure`, `documentai`, `together` and `openrouter` comes back clean | TODO |
| 17 | F20-T17 | Flag rename (app) | `azureOcrEnabled` → `onlineOcrEnabled` across `DailyUsage`, the DTO, the repositories, `DecideAnalysisRoute`, fakes and tests. Azure / Google wording removed from comments | TODO |
| 18 | F20-T18 | `OnlineOcrUnavailableFailure` | New `NetworkFailure` subtype and `api_error_mapper.dart` case; every exhaustive switch updated. Tests | TODO |
| 19 | F20-T19 | Delete the `analyzeImage` chain (app) | Use case, repository and datasource methods, DTO, `ImageAnalysisSource`, the image branches in `/result` and `AnalysisResultCubit`, DI and tests | TODO |
| 20 | F20-T20 | Fallback policy | Pure `shouldFallBackToOnDeviceOcr(AppFailure)` implementing the §1 allowlist, with one test per subtype | TODO |
| 21 | F20-T21 | Stale-request protection | §4 implemented. Tests use completer-controlled fakes to reproduce: retake mid-flight, double retry, close mid-call, and a late stale result | TODO |
| 22 | F20-T22 | Explicit fallback in `OcrReviewCubit` | `ExtractDocumentText` injected. An allowlisted failure on a current token runs Tesseract on `_photo.path` and then `ExtractCandidates`. `isOffline` becomes `OcrReadMode {online, offline, onlineFallback}`. O14 / O15 behave as specified. Cubit tests cover every client-side O-row | TODO |
| 23 | F20-T23 | Fallback banner | Reuses the amber `_OfflineWarning` component. `ocrOnlineFallbackWarning` — ar: «القراءة الأونلاين مش متاحة دلوقتي، فقرينا الورقة على موبايلك. النتيجة ممكن تكون أقل دقة — راجع النص كويس قبل ما تكمل.» / en: "Online reading isn't available right now, so we read the paper on your phone. Results may be less accurate — check the text before continuing." Widget test under RTL and Large Text | TODO |
| 24 | F20-T24 | Privacy copy (image) | Built on F18-T02's wording. ar: «لما تكون متصل بالإنترنت، بنبعت صورة الورقة لخدمة خارجية تقرا النص منها. إحنا مابنحفظش الصورة، لكن الخدمة دي ممكن تحتفظ بيها فترة، وممكن يراجعها موظفين عندها لتحسين خدمتها. من غير إنترنت، الصورة بتتقري على موبايلك بس.» Privacy policy screen and `CLAUDE.md` §7 / §9 updated. No provider named | TODO |
| 25 | F20-T25 | Explicit-fallback app test | `explicit_ocr_fallback_test.dart` replaces `no_silent_ocr_fallback_test.dart`. Allowlisted failure → Tesseract runs exactly once and the banner shows. A non-allowlisted failure never constructs `OcrEngine`. Consent declined → no network call and no Tesseract | TODO |
| 26 | F20-T26 | Docs | `README.md`, `API_CONTRACT.md`, `TEST-BUILD-ROLLOUT.md`, `supabase/README.md`; "superseded by F20" notes added to the F13 and F18 docs; memory updated | TODO |
| 27 | F20-T27 | E2E verification | **Automated:** suites cover every row O1–O16 and A1–A10. **Live** (local stack + physical device): happy path; bad Gemini key → error with no Tesseract (O6); airplane mode after routing → Tesseract with banner (O7); flag off mid-flow → Tesseract with banner (O10); bad Mistral key → error with no Groq (A6); bad `MISTRAL_MODEL` → no Groq (A7); stale Retake; offline route unchanged. Transient provider rows are covered by fakes only, and this is stated in the report. Both quality gates green. Production flip only after owner confirmation | TODO |

---

## Gate protocol

- **One task at a time.** A task is marked DONE here, then committed and pushed
  (one commit per task), before the next one starts.
- **Server gate:** `deno fmt --check`, `deno lint`, `deno check`, `deno test`.
- **Flutter gate:** `dart format .`, `flutter analyze`, `flutter test`.
- **`/flutter-code-review`** runs before any task is marked DONE.
- **T09 is a hard stop.** No wiring task (T10 onward) starts until the owner
  signs off on the benchmark results. *(Signed off 2026-09-29 on partial
  evidence; see T09.)*
- **Privacy invariants throughout:**
  - No OCR text, prompt, completion, key or document value is ever logged.
  - Provider error bodies are discarded.
  - Images are never persisted on the server.
  - User-facing text never names a provider.
