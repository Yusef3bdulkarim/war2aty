# F36 · Server — `explain-document`

- **Branch:** `feature/explain-document`, cut from `develop` (which carries F35 as of `5c44919`)
- **Milestone:** post-F35, the second feature of the F34 pivot
- **Depends on:** F35 (the two config keys and their `RuntimeConfig` fields are already live in local, staging and production)
- **Runs in parallel with:** F37 (voice spine). Neither touches the UI and they share no code — F34 § "Amendments (2026-11-08)" change #1.
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) — the pivot's decisions record, and its "Amendments (2026-11-08)" section, which wins wherever it disagrees with the body.
- **Progress:** 0 / 21 — D1–D4 answered 2026-11-09; T01's §33 drafted, awaiting approval

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
| **D1** | **Mistral OCR is leg 3.** The account carries a **$10 monthly free credit**, of which **~$4 is budgeted for OCR** — so this is free-tier spend, not a paid plan, and the no-paid-upstream constraint holds. At ~$4/1,000 pages that is **~1,000 pages a month**: a fallback for exhausted Gemini buckets, not a second engine. **T08 is unconditional.** |
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

- [~] **T01** `docs/API_CONTRACT.md` **§33 · `explain-document`** in §30's style:
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
      > **DRAFTED 2026-11-09, awaiting approval.** §33 is in
      > `docs/API_CONTRACT.md` (§33.1–§33.10), marked DRAFT in its own first
      > line, with eight worked examples: electricity bill, school letter, bank
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
      > **Still owed before this box closes:** the owner's answer on the four
      > points raised with the draft (the uncertainty policy, `date.text`'s
      > voice-only role, the `unsupported` screen, and the length caps), then
      > his approval.
- [ ] **T02** **GATE · the Gemini Live spike** (F34-T14), pulled forward from
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
- [ ] **T03** Confirm the reading chain's real inputs: a
      `supabase/tools/list-gemini-models.ts` (the shape of
      `list-gemma-models.ts`) listing the image-capable models the production
      key can actually reach, so "Gemini 3.5 Flash-Lite" and "Gemini 3.1
      Flash-Lite" become two verified model ids and two verified daily buckets
      rather than two names. Plus **D1**: the owner checks whether the free
      Mistral plan can call `/v1/ocr` at all. *Done when:* the two Gemini model
      ids and their per-day limits are recorded in this file, and D1 is answered
      yes or no.

### Phase B — quota and config

- [ ] **T04** Migration `supabase/migrations/<ts>_explain_quota.sql`: insert
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
- [ ] **T05** `get-usage` carries `explain_enabled` (the dependency F35 hands
      over): add it to `UsageResponseBody` and the handler, with the dartdoc-style
      header `online_ocr_enabled` has — why it is here, who reads it, and that an
      absent value reads as `false`. Update **API_CONTRACT §32** and its field
      table. *Done when:* `deno task test` passes, a test asserts the other eight
      fields are unchanged, and a test asserts the flag is reported as `false`
      when the key is absent, unreadable or "off".

### Phase C — the reading chain (image → text)

- [ ] **T06** Generalise the chain to N legs: `_shared/ai/leg-chain.ts` holding
      the deadline, the attempt cap, the `minFallbackMs` rule and the
      `isFallbackEligible` routing, over a `readonly legs: Leg[]` of any length;
      `createFallbackAnalysisProvider` becomes a two-leg caller of it and
      `ProviderName` widens to include the reading providers. **A pure refactor:
      no behaviour change, and the existing `analyze-document` tests are the
      proof.** *Done when:* `deno task test` passes with no test edited except
      for renamed symbols, and a three-leg chain has its own tests covering
      every-leg-fails, second-leg-succeeds and no-time-for-leg-3.
- [ ] **T07** The reading chain: Gemini primary → Gemini secondary (the two ids
      from T03) → [Mistral OCR, if D1 allows] → all failed. Both Gemini legs
      reuse `createGeminiOcrClient` with different model ids; the stage has its
      own deadline inside T15's budget. When every leg fails the handler answers
      the code T17's table assigns, which the client speaks as
      "جرب كمان شوية". *Done when:* unit tests cover each leg succeeding, each
      failing over, a non-eligible failure (`auth`, `bad_request`) **not**
      failing over, and the all-failed mapping.
- [ ] **T08** *(D1 answered: in)* `_shared/ai/mistral-ocr-client.ts` for
      `/v1/ocr`: base64 image in, text out, `ProviderFailure` mapping through
      `providerFailureForStatus`, credentials via a `mistralOcrOptionsFromEnv`
      in the house pattern. *Done when:* unit tests cover a success, each HTTP
      failure class, and a malformed body. The ~1,000 pages/month ceiling the
      $4 credit buys is written into its header, so nobody later treats it as a
      second engine.

### Phase D — the explaining chain (text → cards)

- [ ] **T09** `_shared/schemas/explain-output.schema.ts`: the §33 generation
      schema and its `ModelExplanation` types. Strict-subset rules apply —
      `additionalProperties: false` everywhere, every property in `required`,
      optional expressed as a nullable type, no `minLength`/`pattern`/`format`.
      *Done when:* a unit test asserts the schema is strict-subset-legal and
      that every §33 field appears in it.
- [ ] **T10** `_shared/prompts/explain-prompt.ts`: Egyptian colloquial for
      everyone (what is written is what is spoken), **any** paper and not only
      bills, **no card titles** (the app owns titles and icons), **no repetition**
      — `explain` never restates todo/date/caution — and the interim
      prescription/lab lines from F34. *Done when:* prompt unit tests in the
      style of `supabase/tests/.../prompts` pass, including one asserting the
      prompt never asks for a label.
- [ ] **T11** The explaining chain: `ministral-14b` → `gpt-oss-120b` →
      Gemma 4 26B over the **native** client (`responseJsonSchema`, because the
      OpenAI-compatible endpoint does not enforce the schema). Promote
      `gemma-config.ts` / `gemma-native-client.ts` out of EXPERIMENT **only
      after T18 measures the schema-enforcement premise** (trap #2). *Done
      when:* unit tests cover the three-leg routing and the headers no longer
      claim benchmark-only.
- [ ] **T12** Grounding and dedupe (F34-T09): a phone number, amount or date may
      appear in a card **only if it literally appears in the reading** —
      reusing `number-validator`, `date-validator` and `text-matching`'s digit
      folding rather than new logic; duplicate sentences between `explain` and
      the other cards are stripped; bad labels cleaned. The report counts what
      it changed, never what it contained (§51). *Done when:* unit tests cover
      an invented phone number being dropped, an invented amount being dropped,
      a date that is on the page surviving, and a sentence repeated across two
      cards being stripped once.
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
supabase/functions/_shared/ai/mistral-ocr-client.ts      T08 (conditional)
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
| Gemini's two Flash-Lite buckets are smaller than F34 assumes | medium | T03 reads the real numbers off the key before T07 depends on them |

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
