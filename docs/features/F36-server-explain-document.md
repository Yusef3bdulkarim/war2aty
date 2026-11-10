# F36 · Server — `explain-document`

- **Branch:** `feature/explain-document`, cut from `develop` (which carries F35 as of `5c44919`)
- **Milestone:** post-F35, the second feature of the F34 pivot
- **Depends on:** F35 (the two config keys and their `RuntimeConfig` fields are already live in local, staging and production)
- **Runs in parallel with:** F37 (voice spine). Neither touches the UI and they share no code — F34 § "Amendments (2026-11-08)" change #1.
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) — the pivot's decisions record, and its "Amendments (2026-11-08)" section, which wins wherever it disagrees with the body.
- **Progress:** 9 / 21 — T01–T09 closed, Phases A, B and C done, Phase D started. Reading legs verified with **1,500 RPD each, distinct buckets**; **D1 reopened as D1-bis** (Mistral OCR is refused on the free plan, Groq has no vision model) and leg 3 is a third Gemini id (D1-bis, option 2). **Live reads verbatim (0.0 % WER)**; the page total is capped at **850 characters** (§33.3, measured); Live's free-tier quota is TPM-bound, not RPD-bound. The ephemeral-token question is carried to F37-T15. T06 closed 2026-11-10: the chain runs N legs from `_shared/ai/leg-chain.ts` with **no test file edited** as the proof that `analyze-document` is untouched. T07 closed 2026-11-10: `_shared/ai/reading-chain.ts`, three Gemini ids and **no new transport**, with the stage's own 4 s / 2 s timing derived so all three legs fit D4's 10 s. T08 closed 2026-11-10: `GEMINI_OCR_MODELS` read by `geminiReadingOptionsFromEnv`, missing is fatal — **the secret is not set on staging or production yet; T20 must set it**. T09 closed 2026-11-10: the generation schema, with **one unverified premise handed to T11/T18 — whether any strict provider accepts a nullable object**. **T10 next** — the prompt. One question is carried forward: **what the handler answers for an empty reading** (T07's note, for T15).

## Why this feature exists

Today a paper costs **two** round-trips. `ocr-document` reads the photo and
hands the text plus candidates back to the phone; the user reviews the text;
`analyze-document` classifies and explains it. That shape exists because the
user was assumed to be able to read — the review screen was the whole point.

The pivot removes the reader. A user who cannot read cannot review OCR text, so
the review step is not a safety net any more, it is a dead end. F34's answer is
one call: the phone sends the photo once, the server reads and explains it
server-side, and the response is the cards the result screen draws and the voice
speaks.

This feature builds that endpoint and nothing else. At the end of F36:

1. `POST /functions/v1/explain-document` exists, is deployed, and answers the
   §33 contract — but `explain_enabled` is still `false` in production, so no
   client can reach it and nothing a published user does has changed.
2. `get-usage` carries `explain_enabled`, so F39's capture gate has something to
   read. It was specified in F35's migration header and never implemented —
   F35's own closing note hands this over as "the next feature's first task".
3. `ocr-document` and `analyze-document` are **byte-for-byte unchanged** in
   behaviour. The published 1.0.2 app keeps working through them.
4. The Gemini Live spike has passed or failed on the owner's own machine, so
   F37 either proceeds or the product's voice shape is renegotiated before a
   line of client code is written.

## Scope fence — what this feature does NOT touch

| Not here | Where it goes | Why |
|---|---|---|
| Any Dart file | F38–F41 | F36 is server-only. `flutter test` runs in the gate and must stay green by not being touched. |
| The client reading `explain_enabled` | F39 | F36 only puts the field on the wire. `DailyUsageDto` gains it with the capture gate that needs it. |
| Gemini Live client, ephemeral tokens, audio | F37 | Only the **spike** is here, because its failure invalidates the product. The token endpoint is F37-T15. |
| `ocr-document`, `analyze-document`, `schema_version` | never, until 1.0.x is out of support | F34's first known risk. Both endpoints and that row are frozen. |
| Tesseract and the on-device reading path | F39 | Still the only reading the published app can fall back to. |
| `DocumentAnalysis`, the 7 document tables | F38 | The new JSON shares almost nothing with them; F38 replaces them wholesale. |
| Reminders | out of the pivot | `date` carries a date; the bell is inert until reminders return. |

## Open decisions — ANSWERED by the owner 2026-11-09

All four are settled. The original question and its reasoning are kept below
each answer, because the reasoning is what a later session needs in order to
change the decision safely.

| # | Answer |
|---|---|
| **D1** | ⚠️ **REOPENED by the owner 2026-11-09** — see **D1-bis** below. The original answer is kept for its reasoning. **Mistral OCR is leg 3.** The account carries a **$10 monthly free credit**, of which **~$4 is budgeted for OCR** — so this is free-tier spend, not a paid plan, and the no-paid-upstream constraint holds. At ~$4/1,000 pages that is **~1,000 pages a month**: a fallback for exhausted Gemini buckets, not a second engine. **T08 is unconditional.** |
| **D2** | **`explain_daily_limit` = 5, `daily_limit` stays 3.** Plus a new product rule: **the quota warning appears only during the user's last two attempts** (`remaining_today <= 2`). The server already reports `remaining_today`, so this is a client rule — recorded here and carried to the Home/result work in F41, since F36 touches no Dart. |
| **D3** | **Agreed** — `global_daily_call_cap` moves 500 → 900 in T20's live flip, not in T04's migration. |
| **D4** | **45 s rejected as too long. The budget is 30 s**, split read 10 s / explain 20 s. See the revised D4 below for the measured basis and what 30 s costs. |

### D1 · Mistral OCR as reading leg 3 — ANSWERED: in (blocks T03, T08)

F34 makes Mistral OCR reading leg 3, costed at "~$4 / 1,000 pages from the same
$10/month Mistral credit". Two things in the repo's own record contradict that:
the standing constraint is **free tier only, for every upstream service, never
pay** — and F34 itself records the Mistral account as "Free plan, no payment
method (cannot be charged)".

An account that cannot be charged very likely cannot call a per-page paid
product at all. So the real question is whether leg 3 exists:

- **If it can be called on the free plan** → T08 builds it, and the chain is
  Gemini → Gemini → Mistral OCR.
- **If it cannot** → T08 is dropped, the chain is Gemini → Gemini → the
  "جرب كمان شوية" failure, and the day's reading ceiling is whatever the two
  Flash-Lite buckets give (nominally 500 + 500).

**Answered: it can.** The $10/month credit is free allowance, ~$4 of it
earmarked for OCR, so leg 3 exists and T08 is unconditional. The ceiling it buys
— ~1,000 pages a month, ~33/day averaged — is written into §33.9 so nobody later
mistakes it for a second engine. If the credit is ever spent before the month
ends, leg 3 fails like any other leg and the chain answers the "try later" line.

### D1-bis · Leg 3 under a hard free-tier constraint — ANSWERED: a third Gemini id

**The owner reopened D1 on 2026-11-09:** no paid services and no payment
method, anywhere, ever — restating [the standing constraint]. D1's answer had
rested on the $10 monthly credit being usable free allowance. Two measurements
say leg 3 as planned does not exist:

| Probe | Result |
|---|---|
| `POST /v1/ocr`, `mistral-ocr-latest`, 583-byte PNG | **429** `Rate limit exceeded` (code 1300), no `retry-after` |
| same, `mistral-ocr-2512` | **429**, identical |
| `POST /v1/chat/completions`, `ministral-14b-latest` | **200** — the key and the plan are fine |
| Mistral `GET /v1/models` | 55 models visible, 6 OCR ids among them |

So the account **sees** the OCR models and is **refused at the first call**,
while chat on the same key answers normally. That is a plan gate wearing a
rate-limit's clothes: the free plan serves no OCR. **Mistral OCR is out**, and
with it T08 as written.

Groq was checked as the obvious free alternative — the key already exists and
the OpenAI-compatible client already speaks to it. Its catalogue for this key
is **11 models, text and audio only**: `gpt-oss-120b/20b`, `qwen3.8-27b`,
`allam-2-7b`, two Whisper, two prompt-guards, two Orpheus TTS. **No vision
model**, so Groq cannot read a photo at any price.

What is left, all free:

1. **Two legs, no leg 3.** Delete T08. Honest: T03's numbers show our own
   traffic cannot exhaust 2 × 1,500 RPD behind a 900/day cap.
2. **A third Gemini leg** — `gemini-3.5-flash`, already verified reading the
   probe. Its own bucket and its own 15 RPM, reusing `createGeminiOcrClient`
   with a different id, so **no new client file and no new provider**. Buys
   burst headroom (45 reads/minute instead of 30) and survives one model id
   being retired — which is exactly what just happened to both 2.5 ids. Does
   **not** buy provider diversity: one key, one account, one outage.
3. **On-device Tesseract as the last resort.** Genuinely different failure
   domain and already in the app — but it inverts the call: the phone reads
   and the server would need a **text-in** path, which §33 does not have, and
   a non-reader cannot catch a bad read. That is an F39 shape decision, not a
   leg in this chain.
4. *Rejected:* third-party free OCR APIs. A new processor seeing users' papers
   means new privacy copy and a new trust story for one more leg we do not
   need.

**ANSWERED 2026-11-09: option 2.** The chain is `gemini-3.5-flash-lite` →
`gemini-3.1-flash-lite` → `gemini-3.5-flash`. T08 is a config change, not a
new client; `mistral-ocr-client.ts` is never created; Mistral stays exactly
where it already works, as the **explaining** primary (`ministral-14b-latest`
answered 200 on the same key that refuses OCR).

What option 2 does and does not buy, so nobody later mistakes it for
redundancy: it buys **burst headroom** (45 reads a minute instead of 30) and
survival of one model id being retired — which both 2.5 ids just were. It does
**not** buy provider diversity: one key, one account, one outage takes all
three legs. That is accepted, because the honest failure ("جرب كمان شوية")
is the right answer to a Google-wide outage anyway, and because option 3 —
on-device Tesseract — remains available to F39 if that ever stops being true.
### D2 · `daily_limit` = 5 — ANSWERED: a new key, plus a warning rule (blocks T04)

F34 says the daily limit is 5. `daily_limit` is **one row**, read by
`analyze-document` *and* reported by `get-usage`, which the published 1.0.2 app
displays on Home. Moving it to 5 would hand every published user two extra
analyses and change the Home quota hint with no release.

**Recommendation: a new `explain_daily_limit` key, default 5; `daily_limit`
stays 3.** It is the same reasoning that gave `explain_schema_version` its own
row in F35 — one row read by two contracts is a trap, and the pivot's numbers
should not move the published app's behaviour. Both flows still draw on the same
per-user counter (`analysis_usage_daily`), which is correct: an install is
either a 1.0.x build or a 1.1.0 build, never both, so the counters never
interleave for a single user, and the spend they protect is shared.

**Answered: approved, with an added product rule.** The quota warning is shown
**only during the last two attempts** — `remaining_today <= 2`, i.e. on the 4th
and 5th paper of a Cairo day. Nothing is needed server-side: `get-usage` and the
`explain-document` response path already carry `remaining_today`, and the
threshold is a client constant, deliberately **not** a config row — a row nobody
will ever tune is a row that can only drift from the copy beside it. **This lands
in F41** (Home and مستنداتي), not here, because F36 touches no Dart; it is
recorded in this file so it survives the gap between the two features.

### D3 · `global_daily_call_cap` 500 → 900 — ANSWERED: at the flip (blocks T04, T20)

F34 says 900. The row is currently **500**, armed by F27-T06 against a public
repo and anonymous sign-in. It is a service-wide spend valve shared by both
flows, which is right in principle: both drain the same free tiers.

**Recommendation: raise it to 900 as part of the live flip in T20, not in T04's
migration.** While `explain_enabled` is `false` the only consumer is the old
flow, and 900 would loosen its blast radius for no benefit. The number also
needs the reading chain's real quota math behind it (T03), not F34's estimate.

### D4 · One call now reads *and* explains — ANSWERED: 30 s (blocks T15)

`aiTimeoutSeconds` (25 s, env-overridable) is today the budget for **one** AI
call: `ocr-document` spends all 25 s on Gemini, `analyze-document` spends all
25 s on Mistral-then-Groq. One call doing both, sequentially, does not fit:
Mistral's measured p95 alone was 12.7 s (F20-T09), and a reading leg can burn
18 s before failing over.

**Answered: 45 s is too long. `EXPLAIN_TIMEOUT_SECONDS` = 30 s**, split into a
**read stage of 10 s** and an **explain stage of 20 s**, each with its own
deadline and per-attempt cap. `aiTimeoutSeconds` (25 s) is left exactly as it
is, so the two published endpoints keep the timing F20-T09 tuned them to. The
slot TTL follows the new budget (`+ RESERVATION_GRACE_SECONDS`), and the
client's own timeout must be *longer* than the server's or the server stops
being the one that gives up first — a constraint F39 inherits and T15 writes
down.

**The measured basis** (F20-T09, the only latency numbers this project has):
reading p95 **5.5 s** (2.3 s through the shipped pipeline at T13), explaining
p95 **12.7 s** with the slowest call at 14.7 s, Groq p95 **2.5–3.1 s**. So the
p95 round trip is ~18 s of AI time, and 30 s leaves ~12 s of failover slack.

**What 30 s costs, stated honestly.** It is not enough to try all six legs. The
chain tries as many as the remaining time allows, which is the behaviour the
existing `minFallbackMs` rule already implements. The saving grace is that a
**rate limit returns instantly** — so the case legs 2 and 3 exist for (a Gemini
daily bucket exhausted, the Mistral token bucket spent) leaves nearly the whole
stage for them. What 30 s genuinely gives up is a **second explain leg after a
slow primary**: if Mistral takes 15 s and then fails, Groq gets 5 s, which is
its p95 and no more. 25 s was considered and rejected for exactly that reason —
it would leave no room at all.

**Product consequence worth naming:** the wait is now ~18 s typically and up to
30 s, not the ~10 s of a single call. F22's wait screen must hold attention for
that long, and its voice line ("استنى شوية وأنا بقراها") is doing more work
than it was written for.

## Existing-code analysis

The backend is in good shape for this. Six things it already has, which F36
should reuse rather than reinvent:

| Already exists | Where | F36 uses it for |
|---|---|---|
| `createEndpoint` — CORS, method check, `x-request-id` echo, `no-store`, error envelope | `_shared/http/endpoint.ts` | the whole transport |
| `withReservedSlot` — atomic reserve, both quotas, release on failure | `_shared/usage/slot-reservation.ts` | the quota, unchanged |
| `ProviderFailure` + the closed fallback allowlist | `_shared/ai/provider-failure.ts` | both chains' failover rule |
| `Deadline`, `attemptCapMs`, `minFallbackMs` | `_shared/time/deadline.ts`, `_shared/ai/chain-timing.ts` | the two-stage budget |
| The Gemini **native** image client | `_shared/ai/gemini-ocr-client.ts` | reading legs 1 and 2 |
| The Gemma **native** client with `responseJsonSchema` | `_shared/ai/gemma-native-client.ts` | explain leg 3 |
| Digit folding + the five extractors | `_shared/analyze/image-ocr-pipeline.ts`, `_shared/extractors/` | grounding candidates |
| The grounding validators (date, number, source, business) | `_shared/validators/` | T12's grounding pass |

### Trap #1 — the fallback chain is hard-wired to exactly two legs

`createFallbackAnalysisProvider` takes `primary` and `fallback` and nothing
else, and `ProviderName` is the literal union `"mistral" | "groq"`. F36 needs
**three** legs on the explain side and two-or-three on the read side. The
chain's timing logic (deadline, attempt cap, "is there time for another?") is
correct and worth keeping; its arity is not.

T06 generalises it to N legs **as a pure refactor with the existing tests as the
proof**, before either new chain is written. Doing it inside a new feature's
chain would mean a behaviour change and a refactor landing in one diff, where a
regression in the published `analyze-document` path cannot be told from the new
code.

### Trap #2 — `gemma-*.ts` is explicitly marked EXPERIMENT and benchmark-only

Both files say "Not wired into production. Benchmark legs only". `GEMMA_MODEL`
is deliberately **not defaulted**, and `gemma-native-client.ts` carries an
unverified premise in its own header: that Gemma 4 honours `responseJsonSchema`
on the native API, which "this client exists to measure". F34 then makes it
explain leg 3 on exactly that premise.

T11 must **measure it before relying on it** (T18's benchmark is where), and
promote the header out of EXPERIMENT only once it has. If the premise is false,
leg 3 is a leg that answers free-form JSON and fails the shape check every time
— which is a chain with two real legs and a decorative third.

### Trap #3 — `analysis_enabled` is a kill switch, `explain_enabled` is an opt-in flag, and they fail in opposite directions

`killSwitch()` reads an absent key as **enabled**; `optInFlag()` reads absent,
unreadable and "off" all as **disabled**. Both apply to this endpoint, and the
order they are checked in is the difference between an honest error screen and a
confusing one. T15 checks `analysisEnabled` first (service-wide, matches the two
published endpoints), then `explainEnabled`. Both answer 503 `ANALYSIS_DISABLED`
— which the client renders as the "our problem" screen, the honest message when
the pipeline is off server-side.

There is no `OCR_UNAVAILABLE` path here. That code exists to tell the app it may
read on the device instead, and after F39 there is no on-device reader to fall
back to. Emitting it would be an instruction the client cannot follow.

### Trap #4 — the response must not carry the reading, but the validators need it

F34: "Never return the raw OCR text to the phone; use it server-side only to
ground phone numbers, amounts and dates." The grounding pass therefore runs
*inside* the handler with the reading in hand, and the response builder is
handed only the explained cards. T15 keeps the reading out of the builder's
**signature**, so a future field cannot leak it by accident, and T19 asserts the
serialised body contains no substring of the reading.

### Trap #5 — `explain_enabled` on `get-usage` is additive and safe, verified

`DailyUsageDto.fromJson` reads named keys only and ignores everything else, so a
new field cannot break the published 1.0.2 app. `online_ocr_enabled` set the
precedent: defaulted rather than required, so an absent value reads as a safe
`false`. T05 follows it exactly, and asserts the rest of the body is unchanged.

### Verified facts the plan rests on

| Fact | Source |
|---|---|
| `explain_schema_version` = `"1.0"`, `explain_enabled` = `false` exist in local, staging and production | F35-T04's apply records |
| `RuntimeConfig` already parses both; no endpoint reads either | `_shared/config/runtime-config.ts` |
| `global_daily_call_cap` is **500**, not unset | `20261006090000_arm_global_daily_call_cap.sql` |
| `daily_limit` is **3** and is reported to the published app | `20260726124644`, `usage-handler.ts` |
| `ERROR_CODES` is a closed list of 12 | `_shared/errors/error-codes.ts` |
| `ProviderFailureKind` is a closed list of 7 | `_shared/ai/provider-failure.ts` |
| Deno tests live in `supabase/tests/{unit,integration,fixtures}`; `deno task test` runs them | `supabase/functions/deno.json` |
| staging has `online_ocr_enabled` = **false** while production has **true** | F35's record — staging is not a faithful rehearsal of the online path |

### What the approved design settles — and where it contradicts F34

Read from the approved canvas's own artboards (`project/Result.dc.html`,
`project/Documents.dc.html`), not from F34's prose. Three of F34's five open
schema questions are answered by the design outright, and two of its stated
decisions are contradicted by it.

**The Result screen is exactly six cards**, in this order, each with a fixed
icon and a fixed Arabic title the **app** owns: شرح الورقة · أعمل إيه؟ · ميعاد ·
خلي بالك · تكلم مين · تروح فين. The status segments are one per *present* card.
`أعمل إيه؟` is a **single paragraph** — there is no sub-list, which is why money
and required documents have to live inside its text.

**Contradiction 1 — there is no paper-type icon anywhere.** F34 says the paper
type drives an icon. The Result header's circle is the **photo thumbnail**; the
six card icons are per-card, not per-type; and مستنداتي's row glyph is a generic
sheet of paper whose accent colour follows the row's **section and playing
state** (amber in «عليها ميعاد», teal while playing, blue in «الباقي»), not the
paper's kind. So `paper_type` has **no consumer**. §33.2 drops it.

**Contradiction 2 — the title is not two words.** The design's own header reads
«جواب من مدرسة النور»: four words, 19 characters. مستنداتي's rows carry
«فاتورة الكهربا», «عقد إيجار الشقة», «إيصال التأمينات» — 14–15 characters,
ellipsised at ~24. §33.1 therefore caps the title at **24 characters and leaves
the word count free**.

**And the design has no uncertainty affordance at all** — no «قراءة غير مؤكدة»,
no «راجع المعلومة», nowhere for a `confidence` or a `basis` to be drawn. That is
a real tension with CLAUDE.md §7, which requires that an unconfirmed number is
never presented as fact. §33.4 resolves it the only way the new screen allows:
**omission rather than hedging.** An ungrounded value is removed, `status`
becomes `"partial"`, and a fixed voice line says something on the paper was not
clear. For a user who cannot read, a hedge they cannot see was never protection
anyway.

**The owner approved omission on 2026-11-09**, over the alternative of adding
an uncertainty treatment to the Result design.

**One thing the design is missing, and F40 must add:** the ميعاد card draws
month, day, weekday, time and the bell — and no free text. `date.text` (what the
date is *for*) had nowhere to go. The owner chose to **show it**, so F40 adds a
single line to that card; `project/Result.dc.html` does not have it yet.

## Phases

Each phase ends green: `deno fmt`, `deno check`, `deno task test`, plus
`dart format .`, `flutter analyze`, `flutter test` (which must stay green by
F36 not touching Dart at all). A phase that cannot go green is not finished,
and the next phase does not start. `flutter analyze`/`flutter test` exiting 0 is
**not** a pass on its own — read the counter line.

### Phase A — the contract and the spike

Both are gates. Nothing in Phase C or D is written until T01 is approved,
because the schema is what the server, the DTO, the Drift tables, the cards and
the voice card-splitting all hang off.

- [x] **T01** `docs/API_CONTRACT.md` **§33 · `explain-document`** in §30's style:
      request shape, success response, the generation schema (the strict subset,
      not §33 verbatim — see `analysis-output.schema.ts`'s header for why the
      two differ), the full error-mapping table, and **one worked example per
      paper type** (invoice, school letter, bank letter, government form,
      contract, appointment, prescription, lab result). Resolves the five
      questions F34 left open:
      (a) the two-word title's field name and character cap;
      (b) whether `paper_type` reuses the existing ten `document_type` values or
      shrinks, now that only an icon depends on it;
      (c) where per-card `confidence` and `basis` sit;
      (d) how `todo` phrases itself when `required: false`;
      (e) whether prescriptions and labs are a `paper_type` value or a flag.
      Also records D4's budget decision. *Done when:* the owner approves it in
      writing and `docs/API_CONTRACT.md` carries §33.
      > **APPROVED 2026-11-09.** §33 is in `docs/API_CONTRACT.md`
      > (§33.1–§33.10), with eight worked examples: electricity bill, school letter, bank
      > letter, government form, appointment card, rent contract, prescription,
      > lab result, plus a `status: "unsupported"` body.
      >
      > **Three of the five questions were answered by the approved design, not
      > by judgement** — see "What the approved design settles" above.
      > (a) `paper.title`, **≤ 24 characters, word count free** — the design's
      > own header is four words. (b) **`paper_type` is dropped**: nothing in
      > either artboard renders a per-type icon. (c) **`confidence` and `basis`
      > are dropped**: the new screen has no uncertainty affordance, so
      > grounding is enforced by **omission** (§33.4) instead.
      > (d) `todo.required: false` still carries text, saying what to do with a
      > paper that asks nothing. (e) **prescriptions and labs are neither a type
      > nor a flag** — with `paper_type` gone they are ordinary papers whose
      > wording follows the interim rules, enforced by T13's tests rather than
      > by a wire field.
      >
      > **The four points raised with the draft, all decided by the owner on
      > 2026-11-09:**
      >
      > 1. **Uncertainty — omission approved.** No `confidence`, no `basis`.
      >    An ungrounded value is removed, `status` becomes `"partial"`, and a
      >    fixed voice line says something on the paper was not clear (§33.4).
      > 2. **`date.text` is drawn, not voice-only.** The approved ميعاد card
      >    has no slot for it, so **F40 adds one line to that card** — the one
      >    UI change this contract forces, and the only item F36 hands the
      >    result screen beyond the schema itself. The design canvas's
      >    `project/Result.dc.html` still shows the card without it.
      > 3. **`status: "unsupported"` keeps the drafted handling** — the
      >    ordinary result screen, one honest card, and the slot released so
      >    the retry is free. No fifth failure screen.
      > 4. **Length caps confirmed:** ≤ 24-character title, 1–4 paragraphs of
      >    ≤ 220 characters, ~1,100 characters a page ≈ **75 seconds** of
      >    speech — which is also the per-paper audio budget F37/F38 size
      >    their storage against.
- [x] **T02** **GATE · the Gemini Live spike** (F34-T14), pulled forward from
      14th place because it is the only task whose failure invalidates the
      product's shape. Write `supabase/tools/live-spike.ts` for the owner to run
      on his own machine — the dev sandboxes cannot reach Google — which
      answers **three** questions, not one:
      (i) does Live read the explanation **verbatim**? (compare output
      transcription against the source text, retry on mismatch);
      (ii) is Live available on the **free tier** at all, including
      `POST /v1beta/auth_tokens` for ephemeral tokens?
      (iii) what is the **quota**, read off the owner's own AI Studio
      rate-limit page, since Google no longer publishes Live limits.
      *Done when:* `docs/features/F36-live-spike.md` records the three answers
      with the numbers, and F37 is either cleared to start or blocked with a
      named reason.
      > **TOOL WRITTEN 2026-11-09, the run is owed.**
      > `supabase/tools/live-spike.ts` discovers the model off the key itself
      > (ListModels filtered to `bidiGenerateContent`) instead of hard-coding
      > an id, probes **both** `/v1alpha/auth_tokens` and `/v1beta/auth_tokens`
      > — the task file above assumed v1beta and that was never verified —
      > then runs three read-aloud sessions over the API key and one more over
      > the ephemeral token, which is the exact path the phone would use.
      >
      > Verbatim is judged on Live's own `outputAudioTranscription`, folded
      > (diacritics, tatweel, the alef family, ya, ta marbuta, Arabic-Indic
      > digits) and word-diffed against the source: ≤ 5 % WER verbatim, 5–15 %
      > needs the added/dropped words read, > 15 % paraphrasing. That
      > judgement is the only part of the tool that decides anything, so it is
      > under test — `supabase/tests/unit/live-spike-diff.test.ts`, 11 cases,
      > including audio-with-no-transcription reported as its own outcome
      > rather than a pass. The tool prints no key and no token (an ephemeral
      > token's `name` *is* the credential), and the read-aloud text is
      > invented, so no real paper is ever sent.
      >
      >
      > **RUN 2026-11-09 06:14 UTC — question 1 is answered: Live reads
      > verbatim.** Three sessions on `gemini-2.5-flash-native-audio-latest`,
      > **0.0 % WER each**, byte-identical transcripts, the date and time
      > intact. F37's premise holds. Full record in
      > `docs/features/F36-live-spike.md`.
      >
      > Three things the run turned up that the plan did not expect:
      >
      > 1. **The read is ~26 s for 304 characters** (24 kHz 16-bit mono PCM,
      >    so the byte count gives the spoken length) ≈ **11.3–12.1
      >    characters a second**. §33's approved ~1,100-character page
      >    therefore reads for **~95 s, not the 75 s the caps were approved
      >    against** — and 75 s is also what F38's ~0.3 MB-per-paper audio
      >    budget was sized from. A **~850-character page total** lands back
      >    on 75 s. Owner's call, and the only §33 change in question.
      > 2. **Live streams faster than real time** (11–13 s of wall clock for
      >    25–27 s of audio), so F37 plays the stream rather than waiting for
      >    a finished file — which also helps D4's 30 s budget.
      > 3. **`speechConfig` is rejected outright on v1beta**
      >    (`1007: Unknown name "speechConfig" at 'setup'`), so neither the
      >    language nor the voice can be chosen on that path. The Arabic was
      >    correct anyway, from the text alone.
      >
      > **The token half of question 2 is not answered, and that was this
      > tool's bug:** `auth_tokens` answered 400 `Unknown name
      > "liveConnectConstraints"` on both versions, because that is the
      > *Python SDK's* field name and the REST resource has no such field.
      > Nothing about token availability follows from that 400. The tool now
      > mints from a **minimal body** first (which alone answers
      > availability) and then probes six candidate constraint field names,
      > one request each; a new §2b also asks v1alpha whether the language
      > and voice can be set.
      >
      > **CLOSED by the owner 2026-11-09** on these results, with two
      > decisions and one carry:
      >
      > - **Page total: ≤ 850 characters.** Option 1 — hold the ~75-second
      >   read and F38's ~0.3 MB audio budget rather than accept ~95 s. Now
      >   in §33.3 with the measurement behind it; **T11 and T12 enforce it**
      >   server-side.
      > - **Quota, read off the owner's AI Studio page:** free tier, Gemini
      >   2.5 Flash Native Audio Dialog (Live API) — **RPM unlimited, TPM
      >   1 M, RPD unlimited**, and no session or concurrent-connection cap
      >   listed. So the Live leg is not a daily bucket like the reading
      >   legs; the constraint is tokens per minute, which a 75-second read
      >   is nowhere near. F37 sizes its own backpressure from TPM, not RPD.
      > - **CARRY to F37-T15 — the ephemeral token is still unanswered.** The
      >   fixed payload (minimal body, then six candidate constraint field
      >   names) was never run, so nothing is known about whether the free
      >   tier mints tokens. F37-T15 starts by running
      >   `supabase/tools/live-spike.ts` again; if tokens do not exist, the
      >   voice needs a server relay, because the key cannot ship in the app.
      >   The same run also answers §2b (whether the language and voice can
      >   be chosen at all, since v1beta refuses `speechConfig`).
      >
      > The session itself is proven on the free tier: 4 sessions, no 429,
      > 9 of the key's 61 models advertise `bidiGenerateContent`.
- [x] **T03** Confirm the reading chain's real inputs: a
      `supabase/tools/list-gemini-models.ts` (the shape of
      `list-gemma-models.ts`) listing the image-capable models the production
      key can actually reach, so "Gemini 3.5 Flash-Lite" and "Gemini 3.1
      Flash-Lite" become two verified model ids and two verified daily buckets
      rather than two names. Plus **D1**: the owner checks whether the free
      Mistral plan can call `/v1/ocr` at all. *Done when:* the two Gemini model
      ids and their per-day limits are recorded in this file, and D1 is answered
      yes or no.
      > **RUN 2026-11-09 — the two legs are verified, the buckets are not.**
      > `supabase/tools/list-gemini-models.ts` lists what the key can see, then
      > makes **one real image call per candidate**, because a listed model is
      > not a reachable one. The probe image is generated in the tool (a 260×140
      > PNG of the digits «123»), so a model that answers `123` has *read* an
      > image rather than merely accepted one. `--image=<path>` swaps in a real
      > photo; reading *quality* stays T18's benchmark.
      >
      > **F34's two names are real model ids, and both work:**
      >
      > | id | probe | note |
      > |---|---|---|
      > | `gemini-3.5-flash-lite` | 200, read «123» | what local `GEMINI_MODEL` already pins |
      > | `gemini-3.1-flash-lite` | 200, read «123» | the second leg |
      > | `gemini-2.5-flash-lite` | **404** | *"no longer available to new users"* → use 3.5 |
      > | `gemini-2.5-flash` | **404** | same, → `gemini-3.8-flash` |
      > | `gemini-3.5-flash` | 200, read «123» | heavier backstop if a lite leg dies |
      >
      > Which of the two is **primary** is T18's benchmark to settle, not this
      > run: one call each is a reachability check, and the same model measured
      > 0.7 s and 1.4 s across two runs — a wider spread than between models.
      >
      > **Operational finding, outside F36's scope but not ignorable:** two 2.5
      > ids are now 404 *for new users*. Local pins `gemini-3.5-flash-lite` and
      > is fine. **The production and staging `GEMINI_MODEL` secrets have not
      > been checked** — if either still pins a 2.x id, online OCR for the
      > published 1.0.2 app is already broken or one deprecation away from it.
      > Owner to check; it is a secret, not a repo file.
      >
      > **D1's evidence contradicts the console's wording.** `POST /v1/ocr`
      > (`mistral-ocr-latest`) answered **429** on a single 583-byte image —
      > not 401, so the key is valid and the endpoint exists, but nothing was
      > served. The owner's decision (leg 3 is in, on the $10/$4 free credit)
      > stands, and T08 is still written — but **the leg must not be switched
      > on until a real call succeeds**, which T20's flip now has to verify.
      > Re-run the tool to re-test: it reports the status every time.
      >
      > **CLOSED 2026-11-09 with the owner's numbers.** Both deployed secrets
      > now read `gemini-3.5-flash-lite` (production `ivbpmzasxpphclundjyy`
      > and staging `jecujrsvbmashkpobtsz`), so the 2.x deprecation above is
      > not live anywhere.
      >
      > **The buckets, off AI Studio — free tier, and bigger than F34 assumed:**
      >
      > | model | RPM | TPM | RPD |
      > |---|---|---|---|
      > | `gemini-3.5-flash-lite` | 15 | 1 M | **1,500** |
      > | `gemini-3.1-flash-lite` | 15 | 1 M | **1,500** |
      >
      > **Distinct daily buckets, one per model row** — so 3,000 reads a day,
      > not F34's assumed 500 + 500.
      >
      > This settles the risk row and **kills D1's premise**. T20's global cap
      > is 900 calls a day, so leg 1 alone covers every call the service will
      > make 1.6× over; the two legs together cover it 3.3× over. Our own
      > traffic **cannot** exhaust these buckets, which is the exact job
      > Mistral OCR was brought in to do (D1).
      >
      > **RPD is not the pressure point; RPM is.** 15 requests a minute per
      > model is 30 a minute across two legs. A burst above that answers 429,
      > which `shouldFallBackToOnDeviceOcr`-style routing treats as eligible,
      > so it fails over rather than failing — but a *third* leg would be
      > worth real headroom here, where it is worth nothing against RPD.

### Phase B — quota and config

- [x] **T04** Migration `supabase/migrations/<ts>_explain_quota.sql`: insert
      `explain_daily_limit` = `5` with `on conflict (key) do nothing` (D2).
      **Must not touch `daily_limit`, `schema_version`, `online_ocr_enabled` or
      `global_daily_call_cap`** — the first two gate every published request,
      the third routes its reading, and the fourth moves in T20 instead (D3).
      House-style header explaining why the limit gets its own row. Then
      `RuntimeConfig.explainDailyLimit: number`, default 5, via the existing
      `positiveInteger` helper, with unit tests for absent / blank / malformed /
      valid / zero / negative. *Done when:* applied locally, a before/after dump
      of `app_runtime_config` differs by exactly one added line, and
      `deno task test` passes.
      > **DONE 2026-11-09.** `20261109120000_explain_quota.sql`, applied with
      > `supabase migration up` (not `db reset` — nothing wiped); it was the
      > only pending migration, the local DB having sat at `20261108120000`.
      >
      > **The diff is exactly one added line**, nothing modified, nothing
      > removed:
      >
      > ```
      > 2a3
      > > explain_daily_limit = 5
      > ```
      >
      > The four rows this migration must not touch are untouched, checked by
      > value *and* JSONB type rather than by reading the SQL:
      > `daily_limit number 3`, `schema_version string "2.0"`,
      > `online_ocr_enabled boolean true`, `global_daily_call_cap number 500`.
      > The new row is `number 5`, which is what `positiveInteger` expects.
      >
      > **Proven through PostgREST and the real parser**, not only in SQL —
      > the same three-link check F35-T04 used. PostgREST returns
      > `{"key":"explain_daily_limit","value":5}` with `typeof value ===
      > "number"`, and feeding that actual response through
      > `parseRuntimeConfig` gives `explainDailyLimit 5` **and** `dailyLimit 3`
      > side by side, with `explainEnabled false`, `schemaVersion "2.0"`,
      > `onlineOcrEnabled true`, `globalDailyCallCap 500` all intact.
      >
      > `RuntimeConfig.explainDailyLimit` is in, defaulting to 5 through the
      > existing `positiveInteger` helper — the same fail direction as
      > `dailyLimit` and the opposite of `globalDailyCallCap`, which the tests
      > pin explicitly. **6 new tests** in `runtime-config.test.ts` cover the
      > seeded row, an operator raising it, a numeric string, a fractional
      > value flooring, the malformed set (`"abc"`, null, -5, 0, {}, [], true)
      > falling back to 5 rather than to 0 or unlimited, an absent row, and —
      > the one that matters — **the two quota rows moving independently** in
      > both directions.
      >
      > The migration header records what the plan only implied: that raising
      > `daily_limit` to 5 would have shipped a product change to every
      > published 1.0.2 user through a schema change, and that this file
      > creates no functions on purpose — the `20261007000000` trap applies to
      > any F36 migration that ever does.
      >
      > Gate: **784 passed, 0 failed** (`deno task test`), `deno fmt --check`
      > clean. No Dart touched. **Staging and production are NOT applied** —
      > that is T20's flip, where `global_daily_call_cap` also moves 500 → 900.
- [x] **T05** `get-usage` carries `explain_enabled` (the dependency F35 hands
      over): add it to `UsageResponseBody` and the handler, with the dartdoc-style
      header `online_ocr_enabled` has — why it is here, who reads it, and that an
      absent value reads as `false`. Update **API_CONTRACT §32** and its field
      table. *Done when:* `deno task test` passes, a test asserts the other eight
      fields are unchanged, and a test asserts the flag is reported as `false`
      when the key is absent, unreadable or "off".
      > **DONE 2026-11-09.** `UsageResponseBody` gains `explain_enabled`, the
      > handler fills it from `config.explainEnabled`, and API_CONTRACT §32
      > carries it in both the example body and the field table. F35's
      > hand-over is closed.
      >
      > **Proven over the real wire, not only in unit tests.** The local stack
      > serves no Edge Functions by default — `supabase start` brings up db,
      > rest, auth, kong, studio and pg_meta, and nothing else — so the
      > integration suite had been **skipping all 15 cases**, which is not the
      > same as passing them. With `supabase functions serve` running:
      > **14 passed, 0 failed, 1 ignored** (the live-AI one), including a
      > `get-usage` call that asserts the **whole key list** of the response.
      > Adding a field must add a field: no rename, no reorder, no drop.
      >
      > **The published app is unaffected, by its own code.**
      > `lib/core/usage/daily_usage_dto.dart`'s hand-written `fromJson` reads
      > eight **named** keys and nothing else, and `onlineOcrEnabled` is
      > already `this.onlineOcrEnabled = false` — defaulted, not required.
      > An unknown tenth key is therefore inert for 1.0.2, exactly as
      > `online_ocr_enabled` was before F20-T17 taught the app its name. No
      > Dart was touched to prove this; it is read off the shipped file.
      >
      > **Five new unit tests**, of which two are the ones worth keeping:
      > one drives the **real `parseRuntimeConfig`** rather than a handcrafted
      > config — absent row, `"off"`, `"nonsense"`, `0` and `null` all reach
      > the wire as `false`, and only an explicit `true` flips it — and one
      > asserts `get-usage` still reports **`daily_limit`, not
      > `explain_daily_limit`**, now that T04 created a second quota row. That
      > endpoint serves the published app's counter; F39 reads the new limit
      > through the explain flow, never from here.
      >
      > Phase B gate, all six commands: **789 passed, 0 failed** unit,
      > **14 passed** integration against a real local stack, `deno fmt --check`
      > clean, `dart format` 732 files 0 changed, `flutter analyze` **0 errors
      > 0 warnings** (19 pre-existing infos in files this feature never
      > touches), `flutter test` **2,825 passed, 0 failed** — read off the
      > counter line, not the exit code.

### Phase C — the reading chain (image → text)

- [x] **T06** Generalise the chain to N legs: `_shared/ai/leg-chain.ts` holding
      the deadline, the attempt cap, the `minFallbackMs` rule and the
      `isFallbackEligible` routing, over a `readonly legs: Leg[]` of any length;
      `createFallbackAnalysisProvider` becomes a two-leg caller of it and
      `ProviderName` widens to include the reading providers. **A pure refactor:
      no behaviour change, and the existing `analyze-document` tests are the
      proof.** *Done when:* `deno task test` passes with no test edited except
      for renamed symbols, and a three-leg chain has its own tests covering
      every-leg-fails, second-leg-succeeds and no-time-for-leg-3.
      > **DONE 2026-11-10.** `createLegChain<TInput, TResult>` in
      > `_shared/ai/leg-chain.ts` runs `readonly legs` of any length behind one
      > `Deadline`, and `fallback-provider.ts` is now 90 lines of wiring that
      > builds a one- or two-leg array and supplies the two things that were
      > ever analysis-specific: the `analyze.provider` event name and
      > `analysisApiErrorFor`. The chain is generic over input and result
      > **so that it cannot reach into either** — the privacy rule made into a
      > type, not a comment.
      >
      > **Not one test file was edited.** Not an import, not a symbol: the
      > `DEFAULT_ATTEMPT_CAP_MS` / `DEFAULT_MIN_FALLBACK_MS` pair moved to
      > `leg-chain.ts` and `fallback-provider.ts` re-exports it, which is four
      > lines bought to keep the proof absolute. `fallback-provider.test.ts`
      > (34 cases), `chain-timing.test.ts` and `analyze-handler.test.ts` all
      > pass against the new chain unchanged — **74 passed, 0 failed** for those
      > three files alone. That is the whole argument that the frozen
      > `analyze-document` path is untouched.
      >
      > **One behaviour was deliberately preserved rather than "improved".**
      > The generalisation wanted to report `failover_skipped:
      > "no_fallback_configured"` whenever a chain ran out of legs — which for
      > two legs would have put a new value on the A10 log line, naming a
      > fallback that did exist and did run. The field answers *why a leg was
      > not followed by another*, so it is omitted exactly where there was
      > never another to expect (`failedOver && isLast`). The log keeps its
      > seven fixed fields on every path, at every arity.
      >
      > **What the fixed field set costs at three legs**, recorded so nobody
      > hunts for it later: `primary_failure` is the FIRST leg's kind and
      > `failure` the kind the chain ended on, so a middle leg's kind is not on
      > the line. Adding a field would have broken the key-set assertion that
      > guards the line against leaks, and `provider` already answers the
      > question the log exists for — leg 3 answering means the two buckets in
      > front of it are spent.
      >
      > **`ProviderName` gained `gemini_read_1/2/3` — positions, not model
      > ids.** D1-bis made the reading chain three Gemini ids on one key, and
      > T08 makes those ids operator-settable without a deploy, so a name tied
      > to an id would go stale the first time an operator moved one. `gemma`
      > is NOT added here; T11 adds it with the leg that needs it.
      >
      > **15 new cases** in `supabase/tests/unit/leg-chain.test.ts`, driven over
      > `string → string` rather than a `ModelAnalysis` — a test that handed the
      > chain a real analysis would quietly suggest the chain can read one.
      > Beyond the three the task names (every-leg-fails, second-leg-succeeds,
      > no-time-for-leg-3): an empty chain refused at BUILD time, a bad key on
      > the **second** leg stopping the chain before the third (two legs could
      > only ever test that on the primary), the floor boundary at leg 3 pinned
      > from both sides, three legs not outliving one deadline, and the stage's
      > §31 mapping proved injectable by mapping the same failure to
      > `OCR_UNAVAILABLE` instead of `ANALYSIS_FAILED`.
      >
      > Gate: **804 passed, 0 failed** (`deno task test`; 789 → 804, all 15 new),
      > `deno check **/*.ts` clean, `deno fmt --check` clean **for everything
      > this task touched**. Three files report "Text differed by line endings"
      > — `analysis-provider.ts`, `openai-compatible-client.ts` and
      > `supabase-error-report-store.ts`. They pre-date T06, verified by
      > stashing this work and re-running: 3 before, the same 3 after. They are
      > the known mixed-CRLF set and are left alone.
      >
      > The 69 ignored tests are the integration suite skipping, because
      > `supabase functions serve` is not running — the T05 note explains that
      > trap. T06 adds no wire surface and changes none, so the unit suite is
      > the right proof here; the next endpoint task (T16/T19) needs the stack
      > up again. **No Dart was touched**, so the Flutter half of the gate is
      > unchanged from T05's green run.
- [x] **T07** The reading chain, three legs, all Gemini (D1-bis):
      `gemini-3.5-flash-lite` → `gemini-3.1-flash-lite` → `gemini-3.5-flash` →
      all failed. Every leg reuses `createGeminiOcrClient` with a different
      model id, so the chain gains a leg without gaining a client; the stage
      has its own deadline inside T15's budget. When every leg fails the handler answers
      the code T17's table assigns, which the client speaks as
      "جرب كمان شوية". *Done when:* unit tests cover each leg succeeding, each
      failing over, a non-eligible failure (`auth`, `bad_request`) **not**
      failing over, and the all-failed mapping.
      > **DONE 2026-11-10.** `supabase/functions/_shared/ai/reading-chain.ts`
      > — `createReadingChain` maps model ids onto T06's `createLegChain`, and
      > **builds no transport at all**: `createGeminiOcrClient` already has the
      > shape of a `ChainLeg.run`, `(image, signal) => Promise<GeminiOcrResult>`,
      > so a leg is `{ name, run: createGeminiOcrClient({ ...gemini, model }) }`.
      > The chain gained a leg without gaining a client, exactly as D1-bis
      > intended. **Nothing existing was modified** — T07 is two new files.
      >
      > **The tests drive a fake `fetch`, not fake legs.** The claim being
      > tested is that each leg is a REAL Gemini client on a DIFFERENT id, and
      > only the URLs can show that: 31 cases assert the three
      > `:generateContent` URLs in order, one key behind all three, and that
      > the `GeminiOptions.model` the caller passes in (what
      > `geminiOptionsFromEnv` reads for `ocr-document`) is never read with.
      >
      > Beyond the four the task names: an ineligible failure on the **middle**
      > leg stopping the chain, **404 pinned as non-failover** (T03 found both
      > 2.5 ids retired — a stale id must be loud, not quietly routed around),
      > the build-time refusals, and a loop over the closed
      > `PROVIDER_FAILURE_KINDS` asserting **no reading failure can produce
      > `OCR_UNAVAILABLE`** (trap #3), so a kind added later fails the test
      > rather than slipping through.
      >
      > **The stage needed its own cap and floor, and the numbers are derived,
      > not measured.** The analysis chain's 18 s cap inside D4's 10 s reading
      > budget would have let leg 1 eat the stage and made legs 2 and 3
      > decorative. The constraint used instead is that **all three legs stay
      > reachable when every one of them hangs**: `4 s + 4 s + 2 s = 10 s`
      > exactly, which a test pins as an identity rather than as three magic
      > numbers. T03's probes read a page in 0.7–1.4 s, so a 4 s cap is ~3× the
      > slowest reading seen; **T18 measures real pages and may move it.**
      > `DEFAULT_READ_STAGE_SECONDS = 10` is exported here for T15 to split the
      > request with.
      >
      > **Two scope lines held on purpose:**
      > - **The model ids are required, never defaulted.** Same reason
      >   `GEMINI_MODEL` is not defaulted (F20 D1): a stale hardcoded id
      >   answers 404 on every photo, which is `bad_request` and so never fails
      >   over — a config slip would become a total outage of reading. T08
      >   supplies them from the environment; whitespace and duplicate cleanup
      >   is T08's too, and the chain only refuses blank and over-long lists.
      > - **At most 3 ids**, because `ProviderName` is a closed union and a
      >   fourth leg would have no name in the log. `MAX_READING_LEGS` is
      >   derived from that list, not written twice.
      >
      > **Open question handed to T15, not answered here:** an empty reading is
      > an ANSWER, not a failure (F20 matrix O2) — a blank page really is
      > blank, and the chain passes `""` through rather than quietly spending a
      > second leg on it. But `explain-document` cannot explain nothing, so
      > **T15 has to decide what the handler answers for an empty reading**;
      > §33 has no "nothing readable" case yet. Routing is the wrong layer to
      > invent one in.
      >
      > The §31 mapping defaults to `analysisApiErrorFor`, which is already
      > what this stage needs (429 → AI_RATE_LIMITED, our budget → TIMEOUT,
      > outage/unusable → ANALYSIS_FAILED, bad key or bad id → INTERNAL_ERROR)
      > and reaches no `OCR_UNAVAILABLE`. It is injectable, so **T17 confirms
      > or replaces it** without touching this file's shape.
      >
      > Gate: **835 passed, 0 failed** (`deno task test`; 804 → 835, all 31
      > new), `deno check **/*.ts` exit 0, `deno lint` clean, `deno fmt --check`
      > clean for both new files. The same pre-existing CRLF set as T06 still
      > reports "Text differed by line endings" and is still untouched. No Dart.
- [x] **T08** *(rewritten by D1-bis — no new client)* The third reading leg is
      a **model id, not a provider**: `GEMINI_OCR_MODELS` (or three discrete
      env names, whichever reads better next to `geminiOptionsFromEnv`) so the
      chain's ids are operator-settable without a deploy, exactly as
      `GEMINI_MODEL` already is. Header records **why** Mistral OCR is absent
      — free plan answers `/v1/ocr` with 429 at the first call, chat on the
      same key answers 200, and the project takes no paid tier — so nobody
      re-adds it from F34's prose. *Done when:* unit tests cover a missing
      value, one id, three ids, and whitespace/duplicate ids, and T07's chain
      is built from it.
      > **DONE 2026-11-10.** `geminiReadingOptionsFromEnv` in
      > `_shared/ai/gemini-config.ts` reads `GEMINI_OCR_MODELS` — one
      > comma-separated variable, not three discrete names — and returns
      > `{ gemini: <key + base URL, no model>, models }`, which is exactly the
      > shape `createReadingChain` takes, so T15 spreads one into the other.
      > One variable because the list *is* the chain: its order is the
      > failover order, and three names would make "which is leg 2" a
      > cross-reference.
      >
      > **The cleaning rules, each with a test:** entries are trimmed and
      > empty ones dropped (a trailing comma or newline is the ordinary slip);
      > a **repeated id keeps its first position**, because two legs on one id
      > share a quota bucket and the second would only repeat the 429 the
      > first just earned; duplicates are counted *after* de-duplication
      > (`a,b,a,c` is three legs); and a **fourth distinct id is refused
      > rather than truncated**, since dropping the tail would run a different
      > chain from the one the operator wrote. Every message names the
      > variable, never a value.
      >
      > **Missing is fatal, not defaulted** — same rule as `GEMINI_MODEL`
      > (D1), and consistent with T07. **That has a deploy consequence:
      > `GEMINI_OCR_MODELS` must be set as a Supabase secret on staging and
      > production before `explain-document` can serve a request.** It is not
      > set anywhere yet. T20's staging flip must set it; production's does
      > not matter until F44, but should be set in the same `secrets set` call
      > as the key so the two cannot drift. `GEMINI_MODEL` is deliberately
      > *not* consulted as a fallback: it is `ocr-document`'s variable, and a
      > one-leg chain silently standing in for the three D1-bis chose would be
      > a degraded deploy that looks healthy. A test pins that setting it
      > neither satisfies a missing list nor changes a present one.
      >
      > **The Mistral-absence record is in the code, where an operator or a
      > later session will hit it** — the header of the reader, with the two
      > probes (`mistral-ocr-latest` and `mistral-ocr-2512`, both 429 on a
      > 583-byte image; `ministral-14b-latest` 200 on the same key) and Groq's
      > text-and-audio-only catalogue, ending "do not re-add Mistral OCR from
      > F34's prose". `supabase/.env.example` carries a shorter note and
      > `supabase/README.md` the variable's existence.
      >
      > **A small T07 follow-through:** `ReadingChainOptions.gemini` is now
      > `GeminiCredentials` (`GeminiOptions` minus `model`), because the chain
      > never reads one. A full `GeminiOptions` is still assignable, which a
      > test keeps honest. `MAX_READING_MODELS` (reader) and
      > `MAX_READING_LEGS` (chain) guard one fact — `ProviderName` has three
      > reading names — so a test asserts they are equal; if they drifted the
      > reader would accept a list the chain then refuses after the request
      > had begun.
      >
      > **`geminiOptionsFromEnv` is behaviourally unchanged**: its key read
      > was extracted into a shared helper and its existing tests pass
      > unedited, which is what keeps `ocr-document` (frozen) untouched.
      > `ocr-document/index.ts` and `_shared/analyze/*` have no diff.
      >
      > Gate: **849 passed, 0 failed** (`deno task test`; 835 → 849, all 14
      > new: 12 for the reader, 2 for the chain), `deno check **/*.ts` exit 0,
      > `deno lint` clean, `deno fmt --check` clean for the four touched code
      > files. The pre-existing CRLF set still reports line endings and is
      > still untouched. No Dart. **Phase C is done.**

### Phase D — the explaining chain (text → cards)

- [x] **T09** `_shared/schemas/explain-output.schema.ts`: the §33 generation
      schema and its `ModelExplanation` types. Strict-subset rules apply —
      `additionalProperties: false` everywhere, every property in `required`,
      optional expressed as a nullable type, no `minLength`/`pattern`/`format`.
      *Done when:* a unit test asserts the schema is strict-subset-legal and
      that every §33 field appears in it.
      > **DONE 2026-11-10.** `_shared/schemas/explain-output.schema.ts` —
      > `EXPLAIN_OUTPUT_SCHEMA`, `EXPLAIN_RESPONSE_FORMAT` (strict `json_schema`,
      > name `document_explanation`) and the `ModelExplanation` types. Two new
      > files; nothing existing modified.
      >
      > **Three decisions the schema makes, each recorded in its header:**
      > - **`partial` is not a status the model can choose.** The enum is
      >   `["success", "unsupported"]`. `partial` means "the server removed
      >   something it could not ground" (§33.4), which only the server knows,
      >   so a model claiming it would be reporting on a check it never ran.
      >   T12 raises `success` to `partial`; the type is `ModelExplainStatus`,
      >   distinct from the wire's status, so that cannot be forgotten.
      > - **The envelope is not asked for.** `explain_schema_version` and
      >   `session_id` are the server's — a model asked to echo a session id
      >   invents one. `paper_type`, `confidence`, `basis`, card titles and any
      >   reading field are absent too (§33.2, §33.3, trap #4), each pinned by a
      >   test rather than by the absence of a line.
      > - **The §33 caps are exported once** — `EXPLAIN_TITLE_MAX_CHARS` 24,
      >   `EXPLAIN_MAX_PARAGRAPHS` 4, `EXPLAIN_PARAGRAPH_MAX_CHARS` 220,
      >   `EXPLAIN_PAGE_MAX_CHARS` 850 — because T10's prompt and T12's
      >   enforcement both need them and two copies drift. The schema itself
      >   cannot carry them (`maxLength` is illegal in strict mode), so they are
      >   stated in the field descriptions and a test asserts the numbers appear
      >   there.
      >
      > **⚠ An unverified premise T11 and T18 must measure, not assume.** The
      > four optional cards are nullable **objects** (`type: ["object",
      > "null"]`). That is standard JSON Schema and what Gemini's
      > `responseJsonSchema` takes, but the analysis schema only ever made
      > *strings* nullable, so **no provider in this project has yet been shown
      > to accept a nullable object in strict mode** — Ministral, `gpt-oss-120b`
      > and Gemma 4 are all untested on it. A provider that rejects it answers
      > 4xx, which is `bad_request` and never fails over: loud, not silent, but
      > it would take a whole leg out. If one rejects, the fallback is not
      > `anyOf` (also unproven) but flattening the card to `{ present: boolean,
      > … }`, which every strict mode accepts. Same shape of risk as trap #2,
      > and the same place to settle it.
      >
      > **The tests would have missed this on the analysis schema's walker.**
      > That one checks `record.type === "object"`, which `["object", "null"]`
      > does not satisfy — it would pass silently on exactly the four new
      > nodes. This file's walker treats a type array containing `"object"` as
      > an object, and **a mutation check proved it bites**: deleting
      > `additionalProperties` from `place` fails with `.properties.place allows
      > extra properties`, and restoring it passes. Keywords are checked as
      > *keys*, not as substrings of the serialised text, so prose in a
      > description cannot trip or hide a violation. It also bans `anyOf`,
      > `oneOf`, `allOf`, `minItems` and `maxItems` beyond the analysis list,
      > since none has been shown to work here.
      >
      > **14 tests**: strict-subset legality (keywords, `additionalProperties`
      > on all 7 objects counted so a lost or added one fails, `required` ==
      > `properties` everywhere), the exact set of nullable nodes (four cards
      > and `date.time` — an accidental extra would let the model omit
      > something §33 says is never null), `explain`/`todo` never nullable, the
      > **exact 18 field paths** §33 says the model writes, and that a typed
      > `ModelExplanation` sample's keys equal the schema's `required` so the
      > interface and schema cannot drift.
      >
      > **Deliberately not here:** a runtime `assertModelExplanation` (the
      > analysis side has `assertModelAnalysis`). It belongs with the leg that
      > needs it — T11 — and writing it now would be code with no caller.
      >
      > Gate: **863 passed, 0 failed** (`deno task test`; 849 → 863, all 14
      > new), `deno check **/*.ts` exit 0, `deno lint` clean, `deno fmt --check`
      > clean for both new files. The pre-existing CRLF set is untouched. No
      > Dart.
- [x] **T10** `_shared/prompts/explain-prompt.ts`: Egyptian colloquial for
      everyone (what is written is what is spoken), **any** paper and not only
      bills, **no card titles** (the app owns titles and icons), **no repetition**
      — `explain` never restates todo/date/caution — and the interim
      prescription/lab lines from F34. *Done when:* prompt unit tests in the
      style of `supabase/tests/.../prompts` pass, including one asserting the
      prompt never asks for a label.
      > **DONE 2026-11-10.** `EXPLAIN_SYSTEM_PROMPT` and
      > `buildExplainMessages({ readingText })`. The §33 caps are interpolated
      > from `explain-output.schema.ts`, so the numbers exist once, and the
      > prompt states the 850-char page total and which strings it sums, which
      > T11's done-when requires. `partial` is never offered (the server's
      > word). The reading is fenced as data and delimiters neutralised.
      >
      > **One existing file touched:** `analysis-prompt.ts` now *exports*
      > `DOCUMENT_OPEN`, `DOCUMENT_CLOSE` and `neutraliseDelimiters` (no
      > behaviour change) so the two prompts share one fence rather than two
      > copies that drift.
      >
      > **Input is the reading only, no candidates.** The explain stage has no
      > on-device candidates (the image path has none); T12 grounds against the
      > reading itself.
      >
      > Gate: **876 passed, 0 failed** (`deno task test` in `supabase/functions`;
      > 863 → 876, all 13 new in `tests/unit/explain-prompt.test.ts`),
      > `deno check` clean, `deno lint` clean, `deno fmt --check` clean. No Dart.
- [ ] **T11** The explaining chain: `ministral-14b` → `gpt-oss-120b` →
      Gemma 4 26B over the **native** client (`responseJsonSchema`, because the
      OpenAI-compatible endpoint does not enforce the schema). Promote
      `gemma-config.ts` / `gemma-native-client.ts` out of EXPERIMENT **only
      after T18 measures the schema-enforcement premise** (trap #2). *Done
      when:* unit tests cover the three-leg routing and the headers no longer
      claim benchmark-only, and the prompt states §33.3's **≤ 850-character page
      total** alongside the per-card caps.
      > **PARTIAL 2026-11-10 — chain built; promotion blocked on T18.** Left
      > unchecked on purpose: the done-when asks for the Gemma headers to stop
      > claiming "benchmark only", and trap #2 forbids that until T18 has
      > *measured* that Gemma 4 enforces `responseJsonSchema`.
      >
      > **Done:** `_shared/ai/explain-chain.ts` — `createExplainChain` (mistral →
      > groq → optional gemma, over T06's `createLegChain`, event
      > `explain.write`), `createExplainLeg`, and `assertModelExplanation` (the
      > runtime check T09 deferred to here; shape only, no caps, no grounding —
      > T12's). One-word change to `leg-chain.ts`: `ProviderName` gains
      > `"gemma"`. The page cap is already in the prompt (T10).
      >
      > **Gemma is an optional leg**, so a two-leg chain is legal and the caller
      > omits it until T18 answers. Timing defaults: 20 s stage, 8 s per attempt,
      > 3 s floor (all three legs reachable when two hang); derived from D4, not
      > measured — T18 records real latency.
      >
      > **Still owed to close T11:** after T18, edit the headers of
      > `gemma-config.ts` / `gemma-native-client.ts` out of EXPERIMENT (or drop
      > the leg if the premise fails). Also unmeasured per provider: the nullable
      > object cards (T09's note). T15 builds the clients from env.
      >
      > Gate: **892 passed, 0 failed** (863 → 876 at T10 → 892; 16 new in
      > `tests/unit/explain-chain.test.ts`), `deno check`, `deno lint`,
      > `deno fmt --check` clean. No Dart.
- [ ] **T12** Grounding and dedupe (F34-T09): a phone number, amount or date may
      appear in a card **only if it literally appears in the reading** —
      reusing `number-validator`, `date-validator` and `text-matching`'s digit
      folding rather than new logic; duplicate sentences between `explain` and
      the other cards are stripped; bad labels cleaned. The report counts what
      it changed, never what it contained (§51). *Done when:* unit tests cover
      an invented phone number being dropped, an invented amount being dropped,
      a date that is on the page surviving, and a sentence repeated across two
      cards being stripped once.
      Also the **page-total check** (§33.3, measured in T02): the sum of every
      string the voice reads is capped at **850 characters** ≈ 75 s at the
      measured 11.3–12.1 characters a second. Over the cap, the last `explain`
      paragraphs go first — never `todo`, `date`, `caution` or `contact`, which
      are what the user acts on. *Also done when:* a test drives a 1,200-character
      response down to ≤ 850 with `todo` and `date` intact.
- [ ] **T13** Interim prescription / lab behaviour (F34-T13) as its own tested
      path: a prescription explains *that* it is a prescription, by whom and
      when, and tells the user to have the pharmacist read the drugs; a lab
      result says to show it to their doctor. **No diagnosis, no drug advice.**
      *Done when:* a test per paper type asserts the shape and asserts no
      medical claim is produced.

### Phase E — the endpoint

- [ ] **T14** `_shared/explain/explain-request.ts`: the image-intake shape,
      `explain_schema_version` compared with `!==` against
      `config.explainSchemaVersion` (400 `UNSUPPORTED_SCHEMA`), `app_version`
      against `minimumAppVersion`, `max_image_bytes`, `session_id`,
      `installation_id`. Modelled on `parseAnalyzeImageRequest` but **separate
      from it** — sharing the parser would couple the new contract to the frozen
      one. *Done when:* unit tests cover a valid body and one per rejection,
      including a `"2.0"` schema value being refused.
- [ ] **T15** `_shared/explain/explain-handler.ts`, the sequence and nothing
      else, with the same header discipline as `analyze-handler.ts` explaining
      **why the order is what it is**: auth → config → `analysisEnabled` →
      `explainEnabled` → parse → build both chains (credentials read **before**
      the reservation, so a deploy fault costs no slot) → reserve slot with
      `explainDailyLimit` → read → explain → ground → respond. Two-stage budget
      per D4; slot released on any failure; the reading never reaches the
      response builder (trap #4). *Done when:* unit tests cover the happy path,
      each gate, a read-stage failure releasing the slot, an explain-stage
      failure releasing the slot, the limit being reached, and the global cap
      tripping.
- [ ] **T16** `supabase/functions/explain-document/index.ts` — wiring only, no
      logic, in the style of the other three entrypoints — plus the
      `config.toml` entry and the deploy note. *Done when:* `deno check` passes
      and the function serves locally against `supabase functions serve
      --env-file supabase/.env` (`[edge_runtime]` is `enabled = false` by
      design, so `supabase start` alone leaves it unserved).
- [ ] **T17** The error-mapping table: every `ProviderFailureKind` from either
      stage onto one of the 12 closed `ERROR_CODES`, written into §33 and
      enforced by a test. **`OCR_UNAVAILABLE` is not reachable here** (trap #3).
      *Done when:* a table-driven test covers every row, and a test asserts no
      code outside `ERROR_CODES` can be produced.

### Phase F — proof

- [ ] **T18** The golden set and the benchmark (F34-T12):
      `supabase/tools/explain-benchmark.ts` plus **generic** fixtures — school
      letter, bank letter, contract, personal letter, government form,
      appointment card, prescription, lab result, and one invoice — not only
      bills. Scores reading accuracy, explanation quality, latency per stage,
      and **Gemma's schema enforcement** (trap #2). *Done when:* the benchmark
      runs on the owner's machine and its numbers are recorded in this file,
      including the per-stage latencies that justify D4's budget.
- [ ] **T19** Integration tests in `supabase/tests/integration` covering the
      endpoint end to end against fakes: the happy path, both gates, the schema
      mismatch, the quota, and **an assertion that no substring of the reading
      appears in the serialised response** (trap #4). *Done when:*
      `deno task test` passes and the no-leak assertion is present.
- [ ] **T20** Live verification. Deploy to **staging**, flip `explain_enabled`
      to `true` there only, run a real photo of each golden-set paper type
      through the real chain, record the numbers, then raise
      `global_daily_call_cap` to 900 (D3) if T18's math supports it.
      **Production stays dark** — `explain_enabled` is flipped there in F44, not
      here. Note staging's `online_ocr_enabled` is `false` while production's is
      `true`; that does not affect this endpoint, which reads neither, but it
      does mean staging is not a rehearsal for anything `ocr-document` related.
      *Done when:* the run's results are in this file and production's
      `explain_enabled` is verified still `false`.
- [ ] **T21** The gate: `deno fmt --check`, `deno check **/*.ts`,
      `deno task test`, `dart format .`, `flutter analyze`, `flutter test`, all
      green with the counter lines read, not the exit codes. Then
      `@code-reviewer` for an independent review, then `/explain-feature`, then
      `@git-expert` for the PR. *Done when:* all six commands are green, the
      review passes, and the PR is open against `develop`.

## Files

**New**
```
docs/features/F36-server-explain-document.md      (this file)
docs/features/F36-live-spike.md                   T02
supabase/migrations/<ts>_explain_quota.sql        T04
supabase/functions/explain-document/index.ts      T16
supabase/functions/_shared/explain/explain-request.ts    T14
supabase/functions/_shared/explain/explain-handler.ts    T15
supabase/functions/_shared/explain/explain-response.ts   T15
supabase/functions/_shared/ai/leg-chain.ts               T06
supabase/functions/_shared/schemas/explain-output.schema.ts  T09
supabase/functions/_shared/prompts/explain-prompt.ts     T10
supabase/functions/_shared/validators/explain-grounding.ts   T12
supabase/tools/list-gemini-models.ts              T03
supabase/tools/live-spike.ts                      T02
supabase/tools/explain-benchmark.ts               T18
supabase/tests/unit/*, supabase/tests/integration/*, supabase/tests/fixtures/*
```

**Modified**
```
docs/API_CONTRACT.md                   §33 new (T01), §32 widened (T05)
docs/features/README.md                the F36 row and the totals
docs/features/F34-non-reader-pivot.md  F36's row marked in progress
supabase/functions/_shared/config/runtime-config.ts   explainDailyLimit (T04)
supabase/functions/_shared/usage/usage-handler.ts     explain_enabled (T05)
supabase/functions/_shared/ai/fallback-provider.ts    becomes a leg-chain caller (T06)
supabase/functions/_shared/ai/gemma-config.ts         out of EXPERIMENT (T11)
supabase/functions/_shared/ai/gemma-native-client.ts  out of EXPERIMENT (T11)
supabase/config.toml                   the new function (T16)
```

**Frozen — a diff here is a bug**
```
supabase/functions/analyze-document/index.ts
supabase/functions/ocr-document/index.ts
supabase/functions/_shared/analyze/*            (except via T06's rename)
```

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| T06's refactor changes `analyze-document`'s behaviour | **high** | Pure refactor, existing tests unedited as the proof; frozen-files list above |
| Gemma does not honour `responseJsonSchema` → explain leg 3 is decorative | medium | T18 measures it before T11 promotes it; a two-leg chain is an acceptable outcome |
| The read+explain budget exceeds the Edge Function wall clock | medium | T18 records per-stage latency; D4's 45 s is a starting point to be measured, not asserted |
| Live fails the spike → the product's voice shape is wrong | **high** | T02 runs first, before any client work; F37 is blocked, not half-built |
| `daily_limit` moved by accident → published users get 5 | **high** | D2's separate key; T04's done-criterion is a one-line dump diff |
| The reading leaks into the response | **high** | Trap #4: it is not in the builder's signature, and T19 asserts the absence |
| Gemini's two Flash-Lite buckets are smaller than F34 assumes | ~~medium~~ **closed** | T03 read the rows: **1,500 RPD each, distinct buckets** (3,000/day) against a 900/day global cap. Bigger than F34 assumed, not smaller. The live constraint is **RPM 15 per model**, which fails over rather than failing |

## Testing

- **Unit** (`supabase/tests/unit`): config parsing, both chains' routing, the
  request parser, the generation schema's legality, the prompt, grounding and
  dedupe, the error mapping.
- **Integration** (`supabase/tests/integration`): the endpoint against fakes —
  happy path, both gates, schema mismatch, quota, slot release on each stage's
  failure, and the no-leak assertion.
- **Benchmark** (T18, owner's machine): nine generic paper types, scoring
  reading, explanation, per-stage latency and Gemma's schema enforcement.
- **Live** (T20, staging only): one real photo per paper type.
- **Privacy assertions:** no test fixture or log line may contain a document's
  content; every new `logEvent` carries ids, counts and failure kinds only (§51).

## Definition of done

1. All 21 tasks checked, each with its note recording what the plan got wrong.
2. `deno fmt --check`, `deno check`, `deno task test`, `dart format .`,
   `flutter analyze`, `flutter test` — all green, counter lines read.
3. §33 approved by the owner and in `docs/API_CONTRACT.md`; §32 widened.
4. T02's three answers recorded, and F37 cleared or blocked with a reason.
5. `explain_daily_limit` applied in local, staging and production;
   `daily_limit`, `schema_version` and `online_ocr_enabled` verified unmoved.
6. `explain-document` deployed and verified live on **staging**;
   production's `explain_enabled` verified still `false`.
7. The published 1.0.2 app verified still working against production —
   `get-usage`, `ocr-document`, `analyze-document` — after the `get-usage`
   change ships.
8. `@code-reviewer` passes, `/explain-feature` delivered, PR open via
   `@git-expert`.
