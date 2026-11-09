# F36-T02 · The Gemini Live spike

**Run on the owner's machine, 2026-11-09 06:14 UTC**, with
`supabase/tools/live-spike.ts` (verdict logic under test in
`supabase/tests/unit/live-spike-diff.test.ts`, 11 cases).

**Status: CLOSED by the owner 2026-11-09.** Question 1 is answered — Live reads
verbatim. Question 3 is answered from his AI Studio page. Question 2 is
answered for the session (it works on the free tier) and **not** for the
ephemeral token: that probe failed on this tool's own payload and the fixed
version was never run, so the token question is **carried to F37-T15**, which
starts by re-running this tool.

**Why this is a gate.** F37 assumes the app can hand Live a finished Arabic
explanation and have it read **that text**, and that the phone can hold a
short-lived token instead of the API key. Question 1 is the one that could have
invalidated the product; it passed.

## How to run it

```bash
deno run --allow-net --allow-env --env-file=supabase/.env \
  supabase/tools/live-spike.ts
```

Flags: `--attempts=3`, `--model=<id>`, `--language=ar-XA`, `--voice=Kore`,
`--out=<path>` (needs `--allow-write`).

The tool prints no key and no token — an ephemeral token's `name` *is* the
credential — and the read-aloud text is an invented school letter, so no real
paper is ever sent.

## 1 · Does Live read the explanation verbatim? — **YES**

Model spiked: **`gemini-2.5-flash-native-audio-latest`**, chosen off the key
itself (ListModels filtered to `bidiGenerateContent`).

| Attempt | WER | Wall clock | Audio | Dropped | Added |
|---|---|---|---|---|---|
| 1 | **0.0 %** | 12.9 s | ~1,260 KiB | none | none |
| 2 | **0.0 %** | 11.0 s | ~1,260 KiB | none | none |
| 3 | **0.0 %** | 13.4 s | ~1,174 KiB | none | none |

Three sessions, three byte-identical transcripts of the 304-character §33 school
letter — no greeting, no commentary, no reworded sentence, and the date «20
نوفمبر» and time «الساعة 10» came back exactly as written. **F37's premise
holds:** Live can be used as a reader, not just as a conversationalist.

Two conditions that produced this result, and that F37 has to keep:

- The verbatim instruction sits in `systemInstruction`, with the text itself as
  the user turn. Live is still a chat model; this is what makes it behave.
- `temperature: 0` and `responseModalities: ["AUDIO"]`, with
  `outputAudioTranscription` on, which is also how F37 can verify a read in
  production without a second STT.

### The reading speed, which was not asked for but changes a decision

The audio is 24 kHz 16-bit mono PCM, so the byte counts give the spoken length
directly: **~25–27 s for 304 characters ≈ 11.3–12.1 characters a second.**

| | Characters | Spoken |
|---|---|---|
| this spike's text | 304 | ~26 s |
| §33's page cap as approved | ~1,100 | **~95–97 s** |
| the 75-second target | **~850** | 75 s |

§33's caps were approved on 2026-11-09 against a **~75-second** read, and that
same 75 s is what F37/F38's ~0.3 MB-per-paper audio budget was sized from. At
the measured speech rate the approved caps read for **~95 seconds**, not 75 —
about 27 % over, and ~390 KB of audio instead of ~300 KB.

The per-card caps do not need to move. What is missing is a **page total**: cap
the whole response at **850 characters** and the page lands back on 75 s.

**Decided 2026-11-09: 850 characters.** The owner chose to hold the 75-second
read and F38's ~0.3 MB-per-paper budget rather than accept a ~95-second read.
The cap is now in §33.3 of `docs/API_CONTRACT.md`, counting every string the
voice reads, and F36-T11/T12 enforce it — over the cap the last `explain`
paragraphs go first, never `todo`, `date`, `caution` or `contact`.

Note also that the wall clock (11–13 s) is *shorter* than the spoken audio: Live
streams faster than real time, so the user starts hearing the paper well before
the whole read has arrived. That is good news for the 30-second budget (D4), and
it means F37 should play the stream, not wait for the file.

## 2 · Is Live on the free tier, and do ephemeral tokens work? — **half**

**The session: yes.** Four WebSocket sessions on a free-tier key, no payment
method, no 429. The key sees **61 models, 9 of which advertise
`bidiGenerateContent`**:

```
gemini-3.8-live                         gemini-2.5-flash-native-audio-latest
gemini-3.8-live-extended-thinking       gemini-2.5-flash-native-audio-preview-09-2025
gemini-3.1-flash-live-preview           gemini-2.5-flash-native-audio-preview-12-2025
gemini-3.5-live-translate-preview       gemini-robotics-er-2-streaming-preview
gemini-3.5-transcribe-live
```

**`speechConfig` is rejected on v1beta.** The first attempt closed with
`1007: Unknown name "speechConfig" at 'setup'`, and the tool's retry without it
succeeded. So on the v1beta Live path neither the language nor the voice can be
chosen — the Arabic came out correct anyway, from the text alone. F37 needs
voice control, so the tool now probes v1alpha for it (§2b).

**The tokens: not answered.** Both versions returned **HTTP 400 —
`Unknown name "liveConnectConstraints" at 'auth_token': Cannot find field`**.
That is this tool's request body being wrong, not Google's answer:
`liveConnectConstraints` is the **Python SDK's** field name and the REST
resource does not carry it. Nothing can be concluded about token availability
from that 400.

Fixed in the tool: minting now starts from a **minimal body**
(`uses`, `expireTime`, `newSessionExpireTime`), which on its own answers whether
the free tier mints tokens at all; then, if one is minted, it tries each
candidate constraint field name in turn (`liveConnectConstraints`,
`bidiGenerateContentSetup`, `liveConnectConfig`, `liveConstrainedSetup`,
`config`, `setup`) and reports which one parses. An unconstrained token is a
finding, not a blocker — it is still single-use and expires in minutes.

## 2b · Can the language and the voice be chosen?

*Awaiting the next run.* The tool now repeats the same read on **v1alpha** with
`languageCode` and a named prebuilt voice, and reports whether the service
accepts them. This is an F37 input, not a gate: a refusal means F37 takes the
default voice.

## 3 · What is the quota? — **TPM-bound, not RPD-bound**

Read off the owner's AI Studio rate-limit page, 2026-11-09:

| | |
|---|---|
| Tier | **free** |
| Model | Gemini 2.5 Flash Native Audio Dialog (Live API) |
| RPM | **unlimited** |
| TPM | **1 M** |
| RPD | **unlimited** |
| Sessions / concurrent connections | not listed |

This is a different shape from the reading legs, which are daily buckets. Live
has **no daily ceiling to exhaust**: the only limit is tokens per minute, and a
75-second read is nowhere near 1 M. So the voice does not need a day-counter of
its own, and `explain_daily_limit` stays what it is — a product decision about
how many papers a user explains per day, not a provider constraint.

Two cautions. The absence of a session cap on the dashboard is not a promise of
one — it is simply not published, and concurrency is the limit a live audio
stream would actually hit first. And the row read is for the 2.5 native-audio
model; if F37 picks `gemini-3.8-live` or `gemini-3.1-flash-live-preview`, its
row has to be read again.

Observed in the run itself: 3 sessions back-to-back, no rate-limit error.

## Decision — **F37 is cleared**

Live reads a supplied Arabic explanation verbatim, streams it faster than real
time, and has no daily ceiling on the free tier. The voice spine can be built as
designed. **T02 is closed.**

What F37 inherits from this spike:

1. **The ephemeral token is an open question, not a yes** (§2). F37-T15 begins
   by re-running `supabase/tools/live-spike.ts`: the minimal-body probe answers
   whether the free tier mints tokens, and the field-name probes answer how to
   constrain one. If tokens do not exist, the voice needs a **server relay** —
   the key cannot ship inside the app. Do not build the token endpoint on the
   assumption that the 400 in §2 was Google's answer; it was this tool's bug.
2. **Voice and language choice is unverified** (§2b). v1beta refuses
   `speechConfig` outright; the same re-run asks v1alpha. A refusal means the
   default voice, which the spike shows reads Arabic correctly from the text.
3. **Play the stream, do not wait for a file** — the audio arrives in half the
   time it takes to speak.
4. **Keep the two conditions that produced 0.0 % WER:** the verbatim
   instruction in `systemInstruction` with the text as the user turn, and
   `temperature: 0` with `outputAudioTranscription` on — which is also how F37
   can verify a read in production without a second STT.
5. **Re-read the quota row** if F37 picks a different Live model than the 2.5
   native-audio one spiked here.
