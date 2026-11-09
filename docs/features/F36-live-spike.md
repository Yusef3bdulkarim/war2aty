# F36-T02 · The Gemini Live spike

**Run on the owner's machine, 2026-11-09 06:14 UTC**, with
`supabase/tools/live-spike.ts` (verdict logic under test in
`supabase/tests/unit/live-spike-diff.test.ts`, 11 cases).

**Status: question 1 answered — Live reads verbatim.** Question 2 is half
answered: the session itself works on the free tier, but the token minting
failed on *this tool's* payload, so it says nothing yet about tokens. Question 3
is still owed. A second run closes both.

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
the whole response at **~850 characters** and the page lands back on 75 s. That
is a one-line addition to §33 and a server-side check in T11/T12, and it is the
owner's call — see "Owed" below.

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

## 3 · What is the quota?

*Awaiting the owner.* No endpoint reports Live limits. From
<https://aistudio.google.com/app/apikey> → this key's **rate limits**: the tier
name, and RPM / TPM / RPD for the model F37 will use, plus whether sessions or
concurrent connections are mentioned at all.

Observed in the run itself: 3 sessions back-to-back, no rate-limit error.

## Decision

**F37 is cleared on the question that mattered.** Live reads a supplied Arabic
explanation verbatim and streams it faster than real time, so the voice spine
can be built as designed.

Owed before it is fully closed:

1. **A second run of the tool** — it answers the token question properly (§2)
   and the voice/language question (§2b). F37-T15 (the token endpoint) must not
   be built until the token half is answered.
2. **The quota numbers** off AI Studio (§3).
3. **An owner decision on the page total**: cap §33's response at ~850
   characters to hold the approved 75-second read, or accept a ~95-second read
   and re-size F38's audio budget.
