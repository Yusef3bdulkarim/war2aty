# F34 · The non-reader pivot — photograph a paper, hear what it says

- **Branch:** `feature/non-reader`, cut from `develop` once F33 has merged back
- **Milestone:** post-F33
- **Depends on:** F20 (OCR / analysis providers), F30 + F31 (reading aloud)
- **Decisions source:** Claude Doc «ورقتي — قرارات التطوير لاتجاه اللي مبيعرفش يقرأ» — https://claude.ai/artifact/M1G8pLXHokQm6QwJWGP68f. **This file is the in-repo copy of everything the code needs**; if the two disagree, ask the owner.
- **Design source (APPROVED 2026-11-08):** canvas «ورقتي — الشاشات الجديدة» — https://claude.ai/artifact/X9rLoR8AHtmrKq3JTDgbVt. Five artboards: `Main.dc.html` (Home), `Crop`, `Waiting`, `Result`, `Documents` (مستنداتي). No artboard exists for the failure screens (F23's are reused, plus a voice line each) or the splash (produced in F43).
- **Progress:** 0 / 39 — **superseded.** This file is now the DECISIONS record; the work is tracked as F35–F44. See § "Amendments (2026-11-08)".

## Who it is for

The whole app now serves people who **cannot read but can read numbers**. They use WhatsApp, voice notes and the camera, and set the app up themselves. Phones are cheap, slow Android devices; the internet comes and goes. The owner's parents test every build.

The goal is to **understand what a paper is and what to do about it** — any paper, not just bills or government forms — in the fewest steps: photograph → «كمّل» → the explanation plays by itself.

**General rule:** every screen with an important message says it out loud; on-screen text stays small, for whoever is helping.

## Decisions the code depends on

### Flow
1. Home → camera (unchanged) → **quality check removed** (image accepted as is) → crop with a single «كمّل» (Back to go back) → **review-text screen removed** → waiting screen → result, which **starts speaking on its own**.
2. **Auto-save** every paper with its image (encrypted) and its explanation audio.
3. The app checks the network **before** capture; offline → the "no internet" screen with its voice line. Papers already explained play offline (their audio is saved). Rejected: queue-and-explain-later, on-device models.

### Server — new Edge Function `explain-document`
- The phone sends the image **once**; the function reads and explains server-side and returns the cards. `ocr-document` and `analyze-document` **stay** for published builds — do not break them.
- **Reading chain:** Gemini 3.5 Flash-Lite (500/day) → Gemini 3.1 Flash-Lite (500/day) → **Mistral OCR** (fallback only: ~$4 / 1,000 pages from the same $10/month Mistral credit) → all failed: user hears "جرب كمان شوية". **Tesseract is removed entirely** (too many errors; also shrinks the APK).
- **Explaining chain:** Mistral `ministral-14b` (~900/day on the free $10) → Groq `gpt-oss-120b` (~110/day) → Gemma 4 26B via the **native** `generateContent` API with `responseJsonSchema` (the OpenAI-compatible endpoint does not enforce the schema). Gemma 4 31B rejected.
- **Limits:** `daily_limit` = 5 per user, `global_daily_call_cap` = 900. The reserved slot is released if any step fails (`withReservedSlot`).
- **Never return the raw OCR text** to the phone; use it server-side only to ground phone numbers, amounts and dates (existing validator).
- Mistral account: Free plan, no payment method (cannot be charged). **Training toggle must be OFF** before launch.

### Output JSON (`explain-document` only)
```json
{
  "explain": ["فقرة 1", "فقرة 2"],
  "todo":    { "required": true, "text": "..." },
  "date":    { "date": "2026-11-20", "time": "10:00", "text": "..." },
  "caution": null,
  "contact": { "name": "مدرسة النور", "phone": "..." },
  "place":   { "text": "مدرسة النور، شارع الجمهورية، دمنهور" }
}
```
- Also: `status`, a two-word paper title (header), paper type (icon), `confidence` and `basis` per card.
- Empty keys are `null` and their card is hidden; `explain` and `todo` are always present (`todo` says what to do with the paper when nothing is required).
- **No repetition anywhere on the page:** `explain` never restates todo/date/caution; the server checks and strips duplicates.
- A phone number must literally appear in the paper for the call button to show (same for amounts and dates).
- The model writes **no card titles** (no more `label_text`); the app owns titles and icons.
- Written in **Egyptian colloquial Arabic for everyone**, because what is written is what is spoken. Smaller response (~300 tokens vs 500).

### Voice
- **Primary:** Gemini Live API (native audio), streamed so speech starts after ~1 s. The phone talks to Gemini with an **ephemeral token** from the server; the key never reaches the device.
- **First implementation step:** verify Gemini Live reads **verbatim** — compare its output transcription with the source text; retry on mismatch.
- Saved once per paper, compressed (~0.5 MB), for offline replay.
- **Fallbacks:** Supertonic 3 on-device (139 MB; project being discontinued; now rarely needed after the offline decision → may be dropped), then device TTS. Number-to-words / code digit-by-digit conversion only on the Supertonic path.
- **Fixed lines (~30)** generated once with Gemini Live in the same voice, shipped as assets; a script the owner runs on his machine (the dev sandboxes cannot reach Google).
- Rejected: Piper (bad voice), Voxtral (eats analysis credit), Google Cloud TTS (needs a card), Azure (free tier not for commercial use), Gemini TTS / Orpheus (10 / 100 per day).

### Screens
**Home** — one job: photograph. Same layout whether new or with 50 papers.
- One-line title «عندك ورقة مش فاهمها؟» (subtitle removed).
- Video button: a WhatsApp-status-style circle next to the title holding a small still/animation from the video (paper + talking phone) and ▶️; its green ring stays until the video has been watched once; tap plays the full video.
- A large shutter in the middle (like the phone camera's), «صوّر ورقتك» small inside; pulses until the first paper, then stops.
- Gallery: a small circle stuck to the shutter, in a **different colour** so it reads as its own button. The «اختار صورة من الموبايل» row is removed.
- Removed from Home: privacy sentence (wrong after auto-save), recent documents, "تذكير قادم" card, empty state.

**Crop** — one «كمّل» button; a «؟» in the header plays video scene 4; voice "اضغط كمّل.".

**Waiting** — the paper image, a scan animation, voice "استنى شوية وأنا بقراها.".

**Result** — calm header, meaning cards, WhatsApp-voice-note player.
- Header: one line — back arrow, small round paper thumbnail, paper title, when it was photographed ("النهارده", "امبارح", "3 نوفمبر"), «؟» at the end. Above it **WhatsApp-status segments**, one per card, equal width, filling with scroll and with the voice (the screen auto-scrolls to the card being spoken).
- Manual scroll while speaking: voice continues, auto-scroll stops until a segment is tapped; tapping a segment jumps to that card and plays it.
- Cards: شرح الورقة (always, 1–4 short paragraphs) · أعمل إيه؟ (always; money and required documents live inside it) · ميعاد (if an important date; date, time, bell button — bell inert until reminders return) · خلي بالك (only a real warning) · تكلم مين (if a phone number is printed; name, number, call button) · تروح فين (if an address; button enlarges it full-screen for a driver). The card being spoken is highlighted.
- Player: fixed at the bottom; play/pause, a waveform that fills (tap to seek), time, speed button cycling 1x → 0.8x → 1.2x (persisted).
- Removed: «نتيجة التحليل», «ملخص المستند», partial-result banner, details card (tables, copy buttons), «المطلوب منك», «تنبيه مهم», «المستندات المطلوبة», «الخطوات بالترتيب», «الشرح التفصيلي», «النص المستخرج», the small player with five modes, the bottom bar (listen / reminder / save). To scan another paper the user goes back Home.
- Deferred cards: money on its own, "who can help", "hear the paper as written".

**Failure screens** — unchanged, plus one recorded voice line each (draft):
| Screen | Voice |
|---|---|
| No internet | "مفيش إنترنت دلوقتي. وصّل الموبايل بالنت وجرّب تاني." |
| Daily limit | "خلّصت ورق النهارده. خلي الورقة معاك وصوّرها تاني بكرة." |
| Unreadable | "مقدرتش أقرا الورقة. صوّرها تاني في نور أوضح، وخلي الورقة كلها جوه الصورة." |
| Our problem | "حصلت مشكلة. استنى شوية وجرّب تاني." |
The "consent off" failure screen is removed.

**مستنداتي** — no search, no filters. Auto-split: papers with an upcoming date on top (nearest first, days left beside it), the rest below (newest first). Row = small paper image + play button; the row opens the paper, the button plays the explanation in the list (filling ring; one paper at a time). Empty state as is + voice line, fix "لما تحفظ" copy (saving is automatic). Paper details = **exactly the new Result screen**, audio from storage. Notes, rename and change-type removed. Delete stays: trash icon at the end + voice confirm "عايز تمسح الورقة دي؟".

**Share from WhatsApp** — the app appears in the Android share sheet for **images** (no PDF); the image opens straight on Crop. The app icon must be distinctive in that sheet.

**Tabs** — unchanged for now (الرئيسية، مستنداتي، التذكيرات، الإعدادات).

**Settings** — unchanged for now, except the "allow sending text for analysis" consent setting, which is removed. ⚠ "طريقة المعالجة" has a "text only" mode that used to show the extracted text, which no longer exists — decide what it does during implementation.

**Privacy** — the privacy/consent screen is removed (owner's decision, risk acknowledged: Play's disclosure policy and Egypt's Data Protection Law 151/2020). Privacy-policy link stays in Settings and the store listing; the Data safety form must stay accurate. The hidden "reader mode" is cancelled.

**Prescriptions & lab results (interim)** — prescription: "دي روشتة من دكتور فلان، بتاريخ كذا، وفيها 4 أدوية. خلي الصيدلي يقرالك الأدوية ومواعيدها." Lab result: "دي نتيجة تحاليل من معمل كذا. وريها لدكتورك عشان يشرحهالك." The full version (three paper types, specialty-based drug suggestions checked against Egypt's registered-drug list, 3 confidence levels, no diagnosis) comes after the last version.

**Animated video & splash** — produced **after the design is locked**; storyboard first. Full video plays once on first launch, then from the Home circle; small clips behind each «؟» (crop → scene 4, result → scenes 6–7). Splash: a 2-second Lottie/Rive animation after the mandatory Android 12 screen. Scene list and draft lines are in the Claude Doc.

### Not in this feature
Reminders & notifications (left as is), voice Q&A, full prescriptions/labs, tabs and settings redesign.

## Tasks

### Phase 0 — Prep
- [ ] **T01** Decide the uncommitted Gemma experiment (`_shared/ai/gemma-config.ts`, `gemma-native-client.ts`, `tools/list-gemma-models.ts`, benchmark changes): commit to this branch as the Gemma fallback.
- [ ] **T02** Owner: Mistral console → Privacy → turn **off** "Allow the use of your API calls to train".
- [ ] **T03** Owner approves the design canvas; screens move into `Waraqti.dc.html`.
- [ ] **T04** Cut `feature/non-reader`; bump `minimum_app_version` strategy noted (old builds keep `analyze-document`).

### Phase 1 — Server: `explain-document`
- [ ] **T05** Output schema + types (strict `json_schema`).
- [ ] **T06** System prompt: Egyptian colloquial, any paper, no card titles, no repetition.
- [ ] **T07** Reading chain Gemini 3.5 → 3.1 → Mistral OCR → "try later".
- [ ] **T08** Explaining chain ministral-14b → gpt-oss-120b → Gemma 4 26B native.
- [ ] **T09** Grounding + dedupe: phone/amount/date must appear in the OCR text; strip duplicates; clean bad labels.
- [ ] **T10** Quota: `daily_limit` 5, `global_daily_call_cap` 900, slot released on failure.
- [ ] **T11** Response never includes raw OCR text.
- [ ] **T12** Golden set of **generic** papers (school, bank, contract, letters — not only bills) + benchmark.
- [ ] **T13** Interim prescription / lab behaviour.

### Phase 2 — Voice
- [ ] **T14** Spike (gate): Gemini Live verbatim reading via output transcription; retry on mismatch.
- [ ] **T15** Ephemeral-token endpoint.
- [ ] **T16** Flutter Live client: streamed playback, card boundaries → timestamps for sync.
- [ ] **T17** Save compressed audio per paper; offline replay.
- [ ] **T18** Fallback path; decide Supertonic keep/drop.
- [ ] **T19** Fixed-lines script for the owner's machine + bundled assets.

### Phase 3 — Capture flow
- [ ] **T20** Remove quality check, review screen, privacy screen, consent setting + its failure screen, Tesseract (packages + traineddata), reader mode.
- [ ] **T21** Network check before capture → no-internet screen.
- [ ] **T22** Crop: single «كمّل» + «؟».
- [ ] **T23** Waiting screen.
- [ ] **T24** Failure screens: one voice line each.

### Phase 4 — Result screen
- [ ] **T25** Cards from the new JSON; conditional cards; titles/icons in app.
- [ ] **T26** Header + status segments; voice/scroll sync; manual-scroll rule; tap-to-jump.
- [ ] **T27** WhatsApp-style player; speed cycle persisted.
- [ ] **T28** Card actions: call, full-screen address, bell placeholder.
- [ ] **T29** Auto-save: encrypted image + audio + result.

### Phase 5 — Home & مستنداتي
- [ ] **T30** Home redesign.
- [ ] **T31** مستنداتي: sections, inline play ring, one-at-a-time; remove search/filters/notes/rename/type; details = Result; delete + voice confirm.
- [ ] **T32** Empty state copy + voice.

### Phase 6 — Share from WhatsApp
- [ ] **T33** Android image share intent → Crop.

### Phase 7 — Video & splash (after design lock)
- [ ] **T34** Storyboard. - [ ] **T35** Video + «؟» clips. - [ ] **T36** Splash animation.

### Phase 8 — Release
- [ ] **T37** Privacy policy + Data safety review; health-app policy check.
- [ ] **T38** Parents' device pass on a cheap phone. - [ ] **T39** Release.

## Known risks
- **Published app:** never change `ocr-document` / `analyze-document` contracts.
- **Privacy screen removal** may get the app flagged on Play; T37 is a hard gate.
- **Free tiers** are the whole budget: Gemini Flash-Lite reading is the narrowest point (~1,000/day).
- **Gemini Live** verbatim reading is unproven until T14.

---

# Amendments (2026-11-08)

Written after a discovery pass over the actual codebase. **Where this section
disagrees with anything above it, this section wins.** The task list above
(T01–T39) stays as the record of what was decided; the work itself is tracked as
the ten features below, which carry their own task files.

## The work is now F35–F44

F34's eight phases were re-cut into ten features, because three pieces of work
the phases assumed were small turned out not to be, and two phases were
needlessly sequential.

| ID | Feature | Depends on |
|---|---|---|
| F35 | Groundwork and safe removals — [task file](F35-groundwork-and-removals.md), **closed 2026-11-09** | — |
| F36 | Server: `explain-document` — [task file](F36-server-explain-document.md), **in progress** | F35 |
| F37 | Voice spine: Gemini Live | F35 |
| F38 | Paper model, auto-save and audio storage | F36 schema, F37 |
| F39 | Capture flow | F38 |
| F40 | Result screen | F38, F37 |
| F41 | Home and مستنداتي | F38, F40 |
| F42 | Share from WhatsApp | F39 |
| F43 | Video, «؟» clips and splash | F39, F40 |
| F44 | Release 1.1.0 | all |

Three changes of substance against F34's phase order:

1. **F36 and F37 run in parallel.** Neither touches the UI and they share no
   code. F34 ran them as Phase 1 then Phase 2 for no reason.
2. **The T14 Gemini Live spike runs FIRST**, during F36. It is the only task
   whose failure invalidates the product's shape, and F34 placed it 14th.
3. **F38 is new.** F34 scattered the data-model work across T25 and T29. The
   new output JSON shares almost nothing with `DocumentAnalysis`, which is
   persisted across seven Drift tables and rendered by two screens and ~10
   `core/widgets/result_*` widgets. Every screen reads the new entity, so it
   gets its own feature, its own schema-v4 migration and its own tests before
   any screen is written.

## The owner's answers

1. **Legacy saved papers:** wiped entirely on upgrade (option c). The wipe must
   also delete the encrypted image files, not just the rows, and the store
   listing's "what's new" must say so. → F38.
2. **`schema_version`:** `explain-document` gets its own `explain_schema_version`
   key, starting at `"1.0"`. The global `schema_version` row stays `"2.0"`
   forever, because [analyze-request.ts](../../supabase/functions/_shared/analyze/analyze-request.ts)
   exact-matches it and changing it would break every published build the moment
   the row changed. → F35-T04.
3. **Audio format:** see "Decisions taken on the owner's behalf" below.
4. **Audio encryption:** same.
5. **Onboarding:** the first-launch intro video replaces `OnboardingScreen`. Until
   F43 builds it, the intro screen stays — but F35-T10 moves the onboarding-flag
   flip onto its own CTA, because `PrivacyScreen` is currently the only thing
   that flips it.
6. **Languages:** both Arabic and English stay. Every string change touches all
   three of `app_strings.dart`, `ar_strings.dart`, `en_strings.dart`.
7. **`ProcessingMode`:** removed entirely. Verified to be read by `SettingsCubit`
   and nothing else — it never drove the analysis flow. → F35-T12/T13.
8. **Reminder ↔ document link:** cut — but **in F38, not F35**. See below.
9. **Platform:** Android only for this pivot. iOS after it. Kept compiling, not
   kept at feature parity.
10. **Voice fallback:** see below.
11. **Schema draft:** see below.
12. **Daily limit:** 5 **successful** explanations per Cairo day. The slot is
    released on any failure (`withReservedSlot`, unchanged).
13. **Offline replay:** as F34 specifies. Replaying a saved paper is free, needs
    no network, and costs no slot.
14. **Network check:** see below.
15. **Fixed voice lines:** see below.
16. **Video asset:** produced by Claude. APK kept as small as the result allows,
    with a size budget proposed alongside the storyboard rather than after the
    asset exists.
17. **Design approval:** granted. The five artboards named at the top of this file
    are the approved source.

## Decisions taken on the owner's behalf

The owner asked for a recommendation on six points and accepted the reasoning.

- **Audio format — AAC-LC in `.m4a`, 24 kHz mono, 32 kbps (~0.3 MB/paper).**
  Gemini Live emits 24 kHz 16-bit mono PCM, which is 48 KB/s: a 75-second
  explanation is ~3.6 MB raw, so 50 papers would be ~180 MB. Encoding uses a
  platform channel (`MediaCodec` + `MediaMuxer`), which adds nothing to the APK.
  `ffmpeg_kit` was rejected (+10–40 MB and GPL variants); raw WAV was rejected on
  disk cost. AAC/MP4 is also iOS's own native format, so a saved paper plays
  unchanged on iOS later — only the encoder and the PCM sink are
  platform-specific, and both sit behind the `AudioEncoder` / `PcmAudioSink`
  domain interfaces for that reason. → F37.
- **Audio encryption — yes, the same `AesGcmFileEncryptor` and key store as the
  image**, decrypted in memory and played through a `just_audio`
  `StreamAudioSource` so no plaintext reaches disk. Encrypting the photo while
  leaving a spoken reading of the same paper in the clear beside it would be
  incoherent, and the privacy policy already promises encryption at rest.
  Documented fallback if `StreamAudioSource` proves unreliable on cheap devices:
  decrypt to cache, play, delete on close. → F37/F38.
- **Voice fallback — Supertonic is CUT.** 139 MB against "minimise the APK" is
  indefensible and the project is being discontinued; the offline decision
  already removed its main justification. Two tiers instead: Gemini Live, then
  **device TTS** (`flutter_tts`, already shipping, with F30/F31's Arabic voice
  selection, number normalisation and chunking), then F30-T07's existing
  "open TTS settings" escape hatch when no Arabic voice is installed. A paper
  read by device TTS saves no audio file; its row records the engine and replay
  re-runs TTS. The ~30 bundled fixed lines mean no UI message ever depends on
  either engine. → F37-T18.
- **Schema draft — one approval document before any server code.** The schema is
  the contract the server, the Flutter DTO, the Drift tables, the result cards
  and the voice card-splitting all hang off. F36's first task produces a new
  `docs/API_CONTRACT.md` section in §30's style, the generation schema, and a
  worked example per paper type, for the owner to approve. Five points F34 leaves
  open are resolved there: the two-word title's field name and cap; whether the
  paper-type enum reuses the existing ten `document_type` values or shrinks now
  that only an icon depends on it; where per-card `confidence` and `basis` sit;
  how `todo` phrases itself when `required: false`; and whether prescriptions and
  labs are a `paper_type` value or a flag. → F36-T01.
- **Network check — keep two checks, but change the second.** Connectivity alone
  would leave users at a dead end whenever the pipeline is killed server-side.
  But today's second check calls `syncUsage()` fresh before *every* capture. New
  shape: a local connectivity check (→ no-internet screen), plus an
  `explain_enabled` flag read from the usage sync **Home already performs on
  load** and cached for the session (→ the "our problem" screen, which is the
  honest message). `analysis_enabled` stays as the server-side 503 backstop.
  One fewer round-trip before every photo. → F35-T04 seeds the key; F39 reads it.
- **Fixed voice lines — derived, then approved, then generated.** Claude writes
  `docs/features/F34-voice-lines.md` (a numbered table: id, Arabic text,
  triggering screen/state, target duration) derived from the screens so nothing
  is missed; the owner edits the Arabic; Claude writes the generator; the owner
  runs it on his own machine, since the dev sandboxes cannot reach Google. A test
  asserts every id in the table has an asset and every asset is referenced, so a
  renamed line cannot ship as silence. ~30 lines ≈ 360 KB. → F37-T19.

## Resequenced: the reminder ↔ document link

The owner's answer to Q8 was to cut the link now. It moves to **F38**, inside the
schema-v4 migration, for two measured reasons:

- The coupling spans **26 files in `lib/` and 20 in `test/`**, running through
  `ResultActionBar`, `ResultDateRow`, `ResultDetailsCard`, `UpcomingReminderCard`,
  `ReminderFormCubit`, `DocumentDetailsScreen` and the result screen — every one
  of which F38, F40 or F41 deletes outright. Cutting it in F35 means rewriting
  code that is about to be removed.
- `Reminders.documentId` is a `references(Documents, #id)` foreign key with
  `onDelete: cascade`. Dropping it needs a table rewrite, and F38 already performs
  one. Doing it in F35 as well would mean two migrations where one will do.

The product decision stands; only its landing point moved.

## Verified against the code — three traps

Recorded here because each would have cost a debugging session, and each is
invisible from the documents alone.

1. **`PrivacyScreen` is the only caller of `OnboardingCubit.complete()`.**
   Deleting it as F34-T20 describes would mean the onboarding flag is never
   flipped, and `_firstRunRedirect` would pin every launch on the intro screen
   with no route to Home. F35-T10 moves that call before F35-T11 removes the
   screen.
2. **`privacyTitle` and `privacyPoint*` are shared** with the settings
   «سياسة الخصوصية» page through `PrivacyPolicyContent`. Only `privacyAgree`
   becomes unused. Removing the point strings would blank that page and break
   five `app_strings_test` privacy-truth assertions.
3. **`ExtractedTextOnlyView` is not the consent screen**, though it looks like
   it: `_FailureBodyState._showText` toggles it for *every* failure kind.
   Removing consent does not orphan it, so it survives until F40.

## Unverified externally — carry into F37's spike

Google's public docs no longer publish Live API rate limits, and do not state
whether ephemeral tokens are available on the free tier at all. Confirmed from
the docs: tokens are minted with `POST /v1beta/auth_tokens`; `newSessionExpireTime`
defaults to 1 minute, `expireTime` to 30 minutes, `uses` to 1; a session must be
resumed every 10 minutes via `sessionResumption`; the feature is in **preview**.
The free-tier numbers must be read off the owner's own AI Studio rate-limit page.
F37's spike therefore gates on three things, not one: verbatim reading,
free-tier availability, and quota.
