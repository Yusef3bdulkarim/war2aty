# F18 · Live test checklist — Gemini vs Groq on real paperwork

The purpose is one decision: **should `gemini_primary_enabled` be flipped on?**
Everything below exists to answer that from real photographs rather than from a
synthetic sample.

The automated preliminary comparison already found Gemini **less complete** on
amounts (see [the T10 section of the feature doc](features/F18-ai-provider-fallback.md)):
on an electricity bill Groq returned the four line items, Gemini returned only
the total. Reproduced twice, identical both times. Your job is to find out
whether that holds on real paper, and whether it matters to a reader.

---

## Part 0 · Prerequisites (do these first, or you will test Groq only)

Nothing in the app needs changing. But **the deployed function does not yet know
about Gemini**, so without these steps every photo is served by Groq and the
comparison is impossible.

### 0.1 Rotate the keys first

Both keys pasted into the working session are compromised and must be replaced:

- Groq → <https://console.groq.com/keys>, revoke and re-issue
- Gemini → <https://aistudio.google.com/apikey>, delete and re-issue

A fresh Groq key also matters practically: the old one already spent part of
today's 200,000-token budget on the T08 gate.

### 0.2 Push the Gemini secrets

Surgical, so nothing else in the project's secrets is touched:

```bash
supabase secrets set \
  GEMINI_API_KEY=<new key> \
  GEMINI_MODEL=gemini-3.1-flash-lite \
  --project-ref jecujrsvbmashkpobtsz
```

⚠ **Both in the same command.** A key without a model throws on every request by
design — loud, quota-free, but a total analysis outage until fixed.

If you would rather use the env file, add both lines to `supabase/.env` first
(it currently has neither) and then
`supabase secrets set --env-file supabase/.env --project-ref jecujrsvbmashkpobtsz`.

### 0.3 Deploy the function

```bash
supabase functions deploy analyze-document --project-ref jecujrsvbmashkpobtsz
```

Verify it took: a photo analysed now should produce an `analyze.provider` log
line (§2 below). **No line at all means the old bundle is still live.**

### 0.4 Raise the daily limit for the session

The per-user cap is **3 successful analyses per Cairo day**. You cannot run this
checklist on 3 photos. Raise it, and put it back afterwards:

```sql
update public.app_runtime_config set value = '20'::jsonb where key = 'daily_limit';
-- afterwards:
update public.app_runtime_config set value = '3'::jsonb  where key = 'daily_limit';
```

### 0.5 Install the build

Already built and signed: `build/app/outputs/flutter-apk/app-prod-release.apk`
(prod flavor, pointed at `jecujrsvbmashkpobtsz`).

---

## Part 1 · The A/B protocol

The app never reveals which provider served it — by design. So the only way to
compare quality by eye is to **photograph the same document twice, once under
each provider**, and switch providers between the two runs with a DB row.

```sql
-- Gemini leads (Groq catches failures)
insert into public.app_runtime_config (key, value)
values ('gemini_primary_enabled', 'true'::jsonb)
on conflict (key) do update set value = excluded.value;

-- Back to Groq leading
update public.app_runtime_config
set value = 'false'::jsonb where key = 'gemini_primary_enabled';
```

No redeploy is needed — the flag is read per request, so the very next photo
uses the new order.

**Faster alternative that spends no quota on duplicates:** analyse each document
once through the app, copy the OCR text off the review screen into a `.txt`, and
run both providers over it at once:

```bash
GROQ_API_KEY=… GROQ_MODEL=openai/gpt-oss-120b \
GEMINI_API_KEY=… GEMINI_MODEL=gemini-3.1-flash-lite \
  deno run --allow-net --allow-env --allow-read \
  supabase/tools/compare-providers.ts bill.txt
```

Leave ~20 seconds between runs, or Groq's 8,000-tokens-per-minute ceiling will
429 and a rate limit will masquerade as a Gemini win.

**Document mix worth covering** — at least one of each, since the failure modes
differ by type: electricity/water/gas bill · medical appointment or prescription
· government letter or notice · school/university paper · a handwritten or
badly-lit one (to see how each degrades).

---

## Part 2 · What to look at, in priority order

### 2.1 In the app, per document

| # | Field on screen | What good looks like | The specific failure to watch for |
|---|---|---|---|
| 1 | **Document type + title** | Matches what the paper obviously is | Type right but title generic/wrong language |
| 2 | **Amounts** | **Every** printed amount, with the payable total among them | ⚠ **The known Gemini weakness: only the total, line items dropped.** Count them against the paper |
| 3 | **Dates** | Every printed date, correct role (deadline vs issued vs appointment) | A deadline classified as `issued` — kills the reminder |
| 4 | **The reminder** | Offered for real future deadlines only | Offered for a past date, or not offered for a real deadline |
| 5 | **«راجع المعلومة» markers** | On anything genuinely unclear on the paper | A shaky reading shown as confident fact, or everything flagged so the flags stop meaning anything |
| 6 | **Summary + actions** | Simple Egyptian Arabic a low-literacy reader follows; says what to DO | Formal MSA, English leaking in, or vague "review the document" |
| 7 | **Key information rows** | The account/meter/reference numbers actually on the page | Missing identifiers, or invented ones |
| 8 | **Warnings** | Medical/legal/government disclaimer where the type calls for it | Absent on a medical paper, or a scary warning on an ordinary bill |
| 9 | **Perceived speed** | Feels acceptable while holding the phone | Gemini measured ~2.4s slower per analysis than Groq |

### 2.2 The numbers, checked against the paper itself

For each document, count on the paper and compare:

- **amounts printed** vs **amounts returned** — the headline metric
- **dates printed** vs **dates returned**
- is the **payable total** present and correct?
- is the **deadline** present, correct, and reminder-worthy?

An amount or date the app never mentions is a worse failure than one it flags as
uncertain.

### 2.3 The logs — Supabase dashboard → Edge Functions → `analyze-document` → Logs

Filter for `analyze.provider`. One line per analysis:

```json
{"event":"analyze.provider","request_id":"…","provider":"gemini","failed_over":false}
```

| Field | Read it as |
|---|---|
| `provider` | Who answered — `gemini` or `groq`. **This is your ground truth for which leg produced the result on screen** |
| `failed_over` | `false` = the primary answered · `true` = the primary failed and the other leg saved it |
| `primary_error_code` | Present only on a failover — what pushed it across (`AI_RATE_LIMITED` is the free-tier signal) |
| `error_code` | Present only when the analysis failed outright |
| `failover_skipped` | Why no second attempt: `no_fallback_configured` (no Gemini key) · `not_provider_fault` (the model answered, answer unusable) · `insufficient_budget` (too little time left) |

Also worth a look: `analyze.provider_misconfigured` means the flag is on but no
Gemini key is set — you are silently getting Groq. And `analyze.completed` carries
`status` and `document_type` for cross-checking.

---

## Part 3 · Fallback behaviour (3 deliberate tests)

| Test | Setup | Expected — the user must never see a difference |
|---|---|---|
| **A · Normal** | Flag on, valid keys | Photo succeeds. Log: `provider: gemini`, `failed_over: false` |
| **B · Primary broken** | Flag on, **deliberately wrong** `GEMINI_API_KEY` | **Photo still succeeds**, normally, no error on screen. Log: `provider: groq`, `failed_over: true`, `primary_error_code: ANALYSIS_FAILED` |
| **C · Both broken** | Both keys wrong | Photo fails with the ordinary Arabic error. Crucially: **the analysis must not count against the daily quota** — check the remaining count on Home before and after |

Test B is the one that matters most: it proves a Gemini outage is invisible to
users. Restore the real key afterwards.

---

## Part 4 · Recording the result

| Document | Type | Amounts on paper | Groq found | Gemini found | Dates ok? | Reminder ok? | Arabic quality | Verdict |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |

**The flip decision:**

- Gemini matches Groq on amounts and dates across the mix → **flip the flag**,
  take the capacity, watch `analyze.provider` for a week.
- Gemini is consistently thinner on amounts (as the synthetic test suggests) →
  **do not flip.** Two options, both good:
  - try `GEMINI_MODEL=gemini-3.5-flash-lite` — a secrets change, no code change,
    then re-run this checklist;
  - or **leave the flag off and keep the Gemini key set**. Groq then serves every
    request at full quality and Gemini answers *only* when Groq has already
    failed — where a thinner answer clearly beats no answer. This captures most
    of the capacity benefit with none of the quality risk, and needs no flag at
    all.

Whatever you decide, record it in the T10 section of the feature doc so the next
person does not re-derive it.

---

## Afterwards

- [ ] `daily_limit` back to `3`
- [ ] Real `GEMINI_API_KEY` restored if test B changed it
- [ ] `gemini_primary_enabled` left in the state you actually want
- [ ] Verdict written into `docs/features/F18-ai-provider-fallback.md`
