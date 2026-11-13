# F36-T02 · Gemini Live spike — raw run

Run at 2026-11-13T03:41:47.924Z · attempts per model: 3

## Models offering `bidiGenerateContent`

64 models visible, 9 support bidiGenerateContent.

- `gemini-3.5-transcribe-live` — Gemini 3.5 Transcribe Live
- `gemini-2.5-flash-native-audio-latest` — Gemini 2.5 Flash Native Audio Latest
- `gemini-2.5-flash-native-audio-preview-09-2025` — Gemini 2.5 Flash Native Audio Preview 09-2025
- `gemini-2.5-flash-native-audio-preview-12-2025` — Gemini 2.5 Flash Native Audio Preview 12-2025
- `gemini-3.1-flash-live-preview` — Gemini 3.1 Flash Live Preview
- `gemini-3.8-live` — Gemini 3.8 Live
- `gemini-3.8-live-extended-thinking` — Gemini 3.8 Live Extended Thinking
- `gemini-robotics-er-2-streaming-preview` — Gemini Robotics-ER 2 Streaming Preview
- `gemini-3.5-live-translate-preview` — Gemini 3.5 Live Translate Preview

Spiking **`gemini-2.5-flash-native-audio-latest`**.

## 2 · Ephemeral tokens (`auth_tokens`)

The minimal body first — on its own it answers whether the free tier mints tokens at all:

- `POST /v1alpha/auth_tokens` → **HTTP 200** — (a token came back; its value is not printed)
- `POST /v1beta/auth_tokens` → **HTTP 200** — (a token came back; its value is not printed)

Tokens work on **v1alpha**: the phone can hold a short-lived token instead of the key.

Now the field that carries the Live constraints — the lock that stops a leaked token from calling anything else. Each candidate gets one request:

- `liveConnectConstraints` → HTTP 400 — unknown field
- `bidiGenerateContentSetup` → HTTP 400 — unknown field
- `liveConnectConfig` → HTTP 400 — unknown field
- `liveConstrainedSetup` → HTTP 400 — unknown field
- `config` → HTTP 400 — unknown field
- `setup` → HTTP 400 — unknown field

An accepted field above is the one F37 constrains its tokens with. If none is accepted the token is unconstrained — a finding, not a blocker: it is still single-use and expires in minutes.

## 1 · Does it read verbatim?

The transcript below is Live's own `outputAudioTranscription` — a machine listening to its own speech — so a small word error rate may be the transcriber's, not the reader's. Read the dropped/added words before judging.

### Attempt 1 — via API key

- took 13.1 s, ~1217 KiB of audio ≈ **26 s spoken** (11.7 characters a second)
- word error rate **0.0%**
- dropped: none
- added: none

```
دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع. المدرسة بتعزمك على اجتماع أولياء الأمور عشان يكلموك عن مستوى أحمد في نص السنة. روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية وكراسة الواجب بتاعة أحمد. الاجتماع يوم 20 نوفمبر الساعة 10 الصبح. لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد.
```

### Attempt 2 — via API key

- took 11.7 s, ~1238 KiB of audio ≈ **26 s spoken** (11.5 characters a second)
- word error rate **0.0%**
- dropped: none
- added: none

```
دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع. المدرسة بتعزمك على اجتماع أولياء الأمور عشان يكلموك عن مستوى أحمد في نص السنة. روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية وكراسة الواجب بتاعة أحمد. الاجتماع يوم 20 نوفمبر الساعة 10 الصبح. لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد.
```

### Attempt 3 — via API key

- took 14.1 s, ~1326 KiB of audio ≈ **28 s spoken** (10.7 characters a second)
- word error rate **0.0%**
- dropped: none
- added: none

```
دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع. المدرسة بتعزمك على اجتماع أولياء الأمور عشان يكلموك عن مستوى أحمد في نص السنة. روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية وكراسة الواجب بتاعة أحمد. الاجتماع يوم 20 نوفمبر الساعة 10 الصبح. لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد.
```

### Same read, but authenticated with the ephemeral token

**Failed**: closed 1008: Permission denied on the service.

### Verdict

**Verbatim** (best WER 0.0%). F37 can proceed as designed.

## 2b · Can the language and the voice be chosen?

The reads above sent no `speechConfig`, because the v1beta Live service rejects that field — so on that path neither the language nor the voice can be set. F37 needs both, so the same read is tried on v1alpha with a language code and a named voice.

**Refused**: closed 1007: Invalid JSON payload received. Unknown name "speechConfig" at 'setup': Cannot find field.. F37 takes whatever default voice the service gives, or voice choice moves to another API surface.

## 3 · Quota

No endpoint reports Live limits, so this part is manual:

1. Open <https://aistudio.google.com/app/apikey> and click this key's **rate limits**.
2. Find the row for `gemini-2.5-flash-native-audio-latest` and write down **RPM, TPM and RPD**, plus the tier name.
3. Note whether the row mentions sessions or concurrent connections at all.

Observed here: 4 session(s), no rate-limit error.

---

Paste this whole block back; it becomes `docs/features/F36-live-spike.md`.