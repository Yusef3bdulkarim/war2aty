# F36-T02 · The Gemini Live spike

**Status: the tool is written, the run is owed.** `supabase/tools/live-spike.ts`
exists, is type-checked, and its verbatim judgement is covered by
`supabase/tests/unit/live-spike-diff.test.ts` (11 cases). Nothing below is
answered yet — the owner runs it on his own machine, because the dev sandboxes
cannot reach Google and question 3 can only be read off his own AI Studio page.

**Why this is a gate.** F37 assumes the app can hand Live a finished Arabic
explanation and have it read **that text**, and that the phone can hold a
short-lived token instead of the API key. If Live paraphrases, or chats, or is
not on the free tier, then F37's shape is wrong — and it is wrong *before* a
line of client code exists, which is the whole point of running this first.

## How to run it

```bash
deno run --allow-net --allow-env --env-file=supabase/.env \
  supabase/tools/live-spike.ts
```

It prints a Markdown report; paste it back and it becomes this file's §"The run".
Useful flags: `--attempts=3` (sessions per run), `--model=<id>` (skip
discovery), `--language=ar-XA`, `--out=<path>` (also write the report to a file,
needs `--allow-write`).

What it does, in order:

1. **ListModels**, keeping only models that advertise `bidiGenerateContent` —
   so the model id comes off the key itself rather than out of a guess.
2. **`POST /v1alpha/auth_tokens`, then `/v1beta/auth_tokens`**, printing the
   HTTP status of each. The task file assumed `v1beta`; both are probed because
   that assumption is unverified.
3. **Three Live sessions over the API key**, each sending the §33 school-letter
   example with a system instruction to read it verbatim, collecting
   `outputAudioTranscription`, and diffing it against the source.
4. **One more session over the ephemeral token**, if one was minted — this is
   the exact path the phone would use.
5. **Quota instructions**, plus whatever rate-limit errors the run itself hit.

It prints no key and no token: an ephemeral token's `name` *is* the credential,
so only "a token came back" is reported. The read-aloud text is invented, so
nothing from a real paper is sent.

## How to read the verdict

The transcript is Live's own transcription of its own speech, so a small word
error rate may be the transcriber's rather than the reader's. The tool folds
diacritics, tatweel, the alef family, ya, ta marbuta and Arabic-Indic digits
before diffing, so spelling variants cost nothing — what is left is words that
were genuinely added or dropped.

| Best WER | Verdict | What it means for F37 |
|---|---|---|
| ≤ 5 % | **verbatim** | proceed as designed |
| 5–15 % | **near-verbatim** | read the added/dropped words: transcription noise passes, the model's own additions do not |
| > 15 % | **not verbatim** | it is paraphrasing; F37's voice has to come from somewhere else |

A session that returns audio but no transcription is reported as its own
outcome, not as a pass — verbatim cannot be judged without an external STT.

## The run

> Paste the tool's report here.

### 1 · Does Live read the explanation verbatim?

*Awaiting the run.*

### 2 · Is Live on the free tier, and do ephemeral tokens work?

*Awaiting the run.* Record the HTTP status of both `auth_tokens` versions, and
whether the token-authenticated session connected.

### 3 · What is the quota?

*Awaiting the run.* From <https://aistudio.google.com/app/apikey> → this key's
rate limits: the tier name, and RPM / TPM / RPD for the model that was spiked,
plus whether sessions or concurrent connections are mentioned at all.

## Decision

*Awaiting the run.* F37 is **blocked** until this says "cleared" with the three
answers above filled in, or "blocked" with a named reason.
