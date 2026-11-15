# F38 · Paper model, auto-save and audio storage

- **Branch:** `feature/paper-model`, cut from `origin/develop` at `4966bc0` (the PR #43 merge, so the tree carries F35 + F36 + F37). Local `develop` is still at `1a4974a` — fast-forward it before cutting.
- **Milestone:** post-F37, the fourth feature of the F34 pivot
- **Depends on:** F35 (closed), F36's §33 contract (closed), F37's voice spine (closed 2026-11-15 with one accepted open defect)
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) — the pivot's decisions record, and its "Amendments (2026-11-08)" section, which wins wherever it disagrees with the body. The owner delegated F38's remaining open points to Claude on 2026-11-15; they are recorded as D1–D15 below and are decisions, not suggestions.
- **Progress:** 1 / 12

## Why this feature exists

F36 built the endpoint and F37 built the voice. Neither can be seen: nothing in
the app calls `explain-document`, and nothing gives F37's audio store a key that
means anything. F34 originally scattered this work across T25 and T29 of the
result screen; the discovery pass pulled it out, because the new JSON shares
almost nothing with `DocumentAnalysis` — which is persisted across **seven Drift
tables** and rendered by two screens and ~10 `core/widgets/result_*` widgets.
Every pivot screen reads the new entity, so it gets its own feature, its own
migration and its own tests **before any screen is written**.

At the end of F38:

1. A §33 response parses into one immutable `PaperExplanation`, with the §33.7
   error table mapped onto the existing `AppFailure` leaves.
2. `POST /functions/v1/explain-document` is reachable from Dart, behind an
   `ExplainPaper` use case.
3. Schema **v4** exists: `papers`, `paper_paragraphs`, `paper_spans`; the legacy
   saved papers and their encrypted images are **gone**; and
   `reminders.document_id` is **dropped**.
4. A paper auto-saves — row, encrypted photo, and the encrypted `.m4a` F37
   writes — and replays offline with its card highlighting intact, because the
   voice spans are persisted with it.
5. The cards map to `List<VoiceSegment>` under one stable id scheme, so a span
   measured today still matches the same card when the paper is re-read a month
   from now.

**No screen.** Nothing is wired into capture, the result screen or مستنداتي;
F39, F40 and F41 do that. The one exception is the dev harness (T12), which
already exists and which F40 deletes.

## Scope fence — what this feature does NOT touch

| Not here | Where it goes | Why |
|---|---|---|
| Any product screen, route or widget | F39, F40, F41 | F38 ends at an injectable repository plus use cases. |
| `explain_enabled` on the client, the capture gate, the network pre-check | F39 | F36 put the flag on the wire; the gate is the capture flow's. |
| Tesseract removal, the quality check, the review screen | F39 | Unrelated to the model. |
| The six cards' layout, the status segments, the player, auto-scroll | F40 | F38 hands it an entity, segments and spans. |
| مستنداتي's sections, the inline play ring, delete + voice confirm | F41 | F38 gives it `watchPapers()` and `deletePaper()`. |
| Dropping the 7 legacy document tables and `DocumentAnalysis` itself | F40 / F41, as schema **v5** | See D3. The legacy *data* dies in v4; the legacy *tables* outlive it by one feature, because their consumers do. |
| `ocr-document`, `analyze-document`, `schema_version` | never, until 1.0.x is out of support | F34's first known risk. Published builds still use all three. |
| The result screen's "partial" voice line | F40 | See "Open for the owner". |
| iOS | after the pivot | Kept compiling. |

## Decisions — delegated to Claude, 2026-11-15

| # | Decision |
|---|---|
| **D1** | **F38 owns the Flutter client for `explain-document`** — request/response DTOs, the datasource, the repository and the `ExplainPaper` use case. The DTO and the entity are one contract; splitting them across two features means writing the mapping tests twice and reviewing the §33 caps twice. F39 gets a use case to call. |
| **D2** | **F38 owns the cards → `List<VoiceSegment>` mapping** and the segment-id scheme. It is pure domain work over the entity F38 defines, and F37 named "F38/F40" for it. F40 consumes it; F41 reuses it for replay. |
| **D3** | **Schema v4 is additive.** It creates the `papers` tables, wipes the legacy document rows *and* their encrypted images, and rewrites `reminders`. It does **not** drop the seven legacy document tables, `DocumentAnalysis`, `DriftDocumentsRepository` or the two mappers — their consumers (the old result screen, `DocumentDetailsScreen`, `DocumentsListScreen`, `SaveDocumentCubit`) are deleted by F40 and F41, and dropping the tables here would mean deleting those screens here. The price is one extra migration (v5, in F41); the gain is that every feature in this chain stays green and reviewable on its own. |
| **D4** | **The reminder ↔ document link is cut here**, as F34 resequenced it: the v4 rewrite drops `reminders.document_id`, and `CreateReminderFromDocumentDate`, `ReminderFromDocumentArgs`, the `/reminders/create` route and the router's two bell helpers go with it. `onCreateReminder` is **nullable** on `AnalysisResultScreen`, `ResultActionBar` and `ResultDetailsCard`, so the old screens simply stop offering the bell — no widget is rewritten. `isManual` **stays** (see D5). |
| **D5** | **`isManual` is kept, though every surviving reminder is now manual.** It is not just a mirror of the column: `ReminderFormState.isManual` drives whether a time is *required* (`eventDate != null && (!isManual || eventMinuteOfDay != null)`) and three branches of `ReminderFormScreen`. Removing it is a rewrite of the reminder form's validation, which F34 explicitly left alone. It is recorded here as dead-but-structural, for F41+ to remove if the bell never comes back. |
| **D6** | **Table shape: `papers` + `paper_paragraphs` + `paper_spans`.** One row per paper holding every single-valued card as nullable columns; the 1–4 `explain` paragraphs in a `position`-keyed child table; the voice spans in another. No JSON column — the project's convention is `position`-keyed children (six of them already), and a JSON blob would be a second serialization format inside the schema with no mapper tests of its own. `paper_spans` is not optional: `VoicePlaybackCubit.replay({audioId, spans})` takes spans, and without them a replayed paper has no card highlighting. |
| **D7** | **Beyond the §33 fields the row carries:** `photographedAt` (distinct from `savedAt` — the header shows when the paper was *photographed*), `eventDay` + `eventMinuteOfDay` **indexed** (denormalised from the `date` card so F41's "upcoming first, nearest first" split is one indexed query, not a scan), `status`, `sessionId`, `explainSchemaVersion`, `encryptedImagePath`, and the voice columns `voiceEngine`, `audioSaved`, `audioVerified`, `audioDurationMs`. There is deliberately **no** `category`, `kind`, `note`, `storageMode` or `extractedText`: the design renders none of them (§33.2), auto-save is unconditional, and the reading is never returned (§33.4). |
| **D8** | **No retention cap in F38.** A paper costs ~0.3 MB of audio plus the photo; the device pass measures the real figure and writes it into this file. A cap — count, bytes, or oldest-first eviction — is a product decision that belongs with مستنداتي (F41) or the release review (F44), and guessing it now would silently delete someone's papers. |
| **D9** | **The row is written when the response arrives, not when the read ends.** F37's audio store is keyed by an id and the `.m4a` is written *during* the read, so the key has to exist first. Order: response arrives → `SavePaper` writes the row and encrypts the photo (`audioSaved: false`) → the read starts with `audioId = paper.id` → `RecordPaperReading` writes `engine`, `duration`, `verified`, `audioSaved` and the spans onto the row. If the app dies mid-read the paper is still there, with no audio; opening it reads it again, which costs a Live session but **no quota slot** (§34: reading is free). |
| **D10** | **`status: "unsupported"` is saved like any other paper.** §33.6 gives it the ordinary result screen with one honest card and releases the slot; a paper the user photographed and heard an answer about should be in مستنداتي, where they can delete it. Not saving it would leave the user with a screen they cannot get back to and no explanation of why this one paper vanished. |
| **D11** | **A device-TTS paper stores no audio and re-speaks on replay** (F37's `VoiceEngine` doc). Its spans are still stored, and still valid on the next read, **because the segment ids are derived from the card structure** (D2) and not from the reading — which is the whole reason the id scheme has to be stable. |
| **D12** | **F38 takes all three of F37's small carry-overs** (T10): `VoiceReadOutcome` gets `==`/`hashCode` (F37 says "worth fixing when F38 starts reading outcomes" — F38 reads them and persists them); the Live socket's **close code and reason are logged** (codes only, §7) so defect 5 can finally identify itself; and `AacEncoder` deletes its zero-byte temp file on a failed read. The second one matters most here: F38 is the first feature to persist `engine`, so "this paper is in the robotic voice" becomes a visible, stored fact. |
| **D13** | **The new image store is a near-copy, not a refactor.** `FilePaperImageStore` mirrors `FileDocumentImageStore` into `paper_images/{id}/image.enc`, exactly as F37's `FileEncryptedAudioStore` mirrored it rather than generalising it. The legacy pair has two features left to live; refactoring a shipping encryption path we are about to delete is the larger risk, and a `get_it` `instanceName` on two instances of one interface is worse than either. The duplication resolves itself in F41. |
| **D14** | **The legacy image files are purged at bootstrap, not in the migration.** `AppDatabase` does no file I/O, and a failed file delete must not block the database from opening. A new step in the existing `BootstrapStage.cleanup` deletes the whole legacy `documents/` directory if it is there. No flag is needed: the directory's absence *is* the flag, and new papers write to a different directory (D13). |
| **D15** | **Client-side caps are tolerated, not enforced.** The server owns §33's caps and trims or re-asks (§33.3). The mapper refuses a response only for *structural* invalidity — a missing `explain` or `todo`, a wrong type, a version mismatch — as `InvalidAnalysisResponseFailure`. A title of 26 characters is drawn, not rejected: refusing a paper the user already paid a slot for because the server was one character generous is the wrong trade. Over-cap values are carried by a test fixture on purpose, so a regression is visible. |

## Open for the owner — two things F38 deliberately does not settle

1. **§33.4 promises a voice line that does not exist.** The contract says an
   omitted value turns `status` to `"partial"` and "a fixed voice line tells the
   user something on the paper was not clear". **None of F37's 12 generated lines
   is that line** — the table has no `partial` row. F38 persists `status`
   faithfully and stops there. **F40 has to either** add the line to
   `F37-voice-lines.md`, have the owner run
   `supabase/tools/generate-voice-lines.ts --only=explain_partial` on his own
   machine (the dev sandboxes cannot reach Google), and bundle it — **or** amend
   §33.4 to drop the promise. Doing it here would mean generating an asset no
   screen can play and no test can prove plays.
2. **The retention cap** (D8), once the device pass has measured what a paper
   actually costs.

## Existing-code analysis — what is reused, and what must not be disturbed

| Thing | Where | How F38 uses it |
|---|---|---|
| `EncryptedAudioStore` / `FileEncryptedAudioStore` | `lib/core/voice/` | unchanged; F38 supplies `paper.id` as the key it was built to receive |
| `AesGcmFileEncryptor`, `FileEncryptor` | `lib/core/crypto/` | encrypts the photo, as it already does for documents |
| `FileDocumentImageStore` | `lib/core/documents/` | the **pattern** `FilePaperImageStore` mirrors (D13) |
| `DefaultAnalysisRepository` | `lib/features/analysis/data/repositories/` | the shape the explain repository copies: `InstallationIdProvider`, `appVersion`, `sessionId`, the schema-version constant, and `failureFromDioException` for the offline/timeout split |
| `EdgeFunctionAnalysisRemoteDataSource` | same feature | the thin-transport pattern; auth, correlation id and logging stay the `Dio` client's job |
| `AnalysisResponseValidator` | same feature | the precedent for "decode, then classify" rather than throwing out of a mapper |
| `Result<T, AppFailure>`, `sealed class AppFailure` | `lib/core/` | **every leaf F38 needs already exists** — see the note below |
| `ReminderScheduler.reconcile()` | `lib/core/reminders/` | already runs at every launch as a deferred bootstrap step, so the OS-side alarms of the reminders v4 deletes are dropped for free |
| `BootstrapStep` + `BootstrapStage.cleanup` | `lib/features/bootstrap/`, `service_locator.dart` | where the legacy image purge is registered (D14) |
| `uuid` | `pubspec.yaml` | `DriftPapersRepository` generates ids the way `DriftDocumentsRepository` does, with an injectable generator for tests |
| `voice_harness_screen.dart` + `VOICE_HARNESS` | `lib/app/dev/`, `app_router.dart` | extended by T12 so F38 has a device trigger; F40 deletes it |

**No new `AppFailure` leaf is needed**, and that is deliberate: §33.7's twelve
codes all land on leaves that already exist (`AnalysisDisabledFailure`,
`InvalidRequestFailure`, `UnsupportedAppVersionFailure`, `UnauthorizedFailure`,
`DailyLimitReachedFailure`, `GlobalCapacityReachedFailure`,
`AiProviderRateLimitFailure`, `RequestTimeoutFailure`, `AnalysisServiceFailure`,
`UnsupportedDocumentFailure`, `InvalidAnalysisResponseFailure`,
`LocalDatabaseFailure`, `FileStorageFailure`, `FileEncryptionFailure`). If a
task finds it needs one anyway, F37-T03's note applies: **one leaf costs five
places**, including `supabase/functions/_shared/reports/error-report-codes.ts`
in the other stack.

**Three things that must stay true.** `ocr-document` and `analyze-document` keep
serving published 1.0.x builds — F38 adds a third client and changes neither.
The old result and details screens must keep **compiling and running** (minus
the bell) until F40/F41 delete them. And nothing F38 writes may log document
content: not the cards, not the title, not a paragraph, not the photo (§7).

## Schema v4 — what the migration actually does

Four steps, in this order, inside `onUpgrade` for `from < 4`:

1. **Create** `papers`, `paper_paragraphs`, `paper_spans` and their indexes
   (parent before children, tables before indexes — the ordering
   `_documentSchema` already follows).
2. **Delete the legacy data.** Every row of the six document child tables, then
   `documents` itself, then **the reminders that pointed at them and their
   alerts** — explicitly, child-first.
   > **The trap:** `PRAGMA foreign_keys = ON` is set in `beforeOpen`, which
   > drift runs **after** `onUpgrade`. Foreign keys are therefore **off** during
   > the migration, so deleting a `documents` row does **not** cascade to
   > `document_dates` or to a linked `reminders` row. A migration that trusts
   > the cascade leaves orphan reminders pointing at papers that no longer
   > exist — and then `reminders.document_id` is dropped and the evidence with
   > it. Delete every table by hand and assert the counts.
3. **Rewrite `reminders`** without `document_id`, with a drift `TableMigration` —
   the table has to be rebuilt because SQLite cannot drop a column that carries
   a foreign key. Its indexes come back minus `reminders_document`. Manual
   reminders survive with every other column intact; this is the one piece of
   user data v4 keeps.
4. **Leave the seven legacy document tables in place, empty** (D3). They are
   dropped in v5, by whichever of F40/F41 deletes their last consumer.

The encrypted *image files* are **not** touched here — D14.

`schemaVersion` becomes `4`. The existing v1→v3 and v2→v3 migration tests must
stay green: a v1 database still has to walk every branch in one open.

## Phases

Each phase ends green: `dart format .`, `flutter analyze`, `flutter test`.
A phase that cannot go green is not finished and the next does not start.
`flutter analyze` / `flutter test` exiting 0 is **not** a pass — read the
counter line, and grep the severities (`flutter-exit-code-0-is-not-a-pass`).

T01 gates everything. T02–T04 are pure domain/data work over it and can run in
any order. T05 gates T06–T09.

### Phase A — the entity and the wire

- [x] **T01** `lib/core/papers/` — the entity. `PaperExplanation` (title,
      `List<String>` paragraphs, `PaperTodo`, and the nullable `PaperDate`,
      `PaperCaution`, `PaperContact`, `PaperPlace`), `PaperStatus`
      (`success | partial | unsupported`), and `SavedPaper` (the entity plus the
      save's bookkeeping and its voice record). In `core/` for the reason
      `core/documents/` is: F39, F40 and F41 all read it, and a feature screen
      never imports another feature. *Done when:* the directory compiles with
      **zero** Flutter, Drift, Dio or Supabase imports, every `toString()`
      reports shapes and lengths rather than content (§7, the guard F37-T03
      wrote), and `==`/`hashCode` are hand-written — no Freezed, no codegen.

- [ ] **T02** `ExplainResponseDto` + `ExplainResponseMapper`: §33's success body
      → `PaperExplanation`, hand-written `fromJson` (json_serializable is
      forbidden). Null cards stay null; `explain` and `todo` are required;
      `explain_schema_version` is compared against
      `RuntimeConfig.explainSchemaVersion`. Caps are tolerated, not enforced
      (D15). *Done when:* the §33.10 worked examples parse byte-for-byte, a
      missing `todo` is `InvalidAnalysisResponseFailure`, a wrong-typed `date`
      is the same, a paper with every optional card null round-trips, and an
      over-cap title is accepted with a test that says so on purpose.

- [ ] **T03** `ExplainRequestDto` + `EdgeFunctionExplainRemoteDataSource` +
      `DefaultExplainRepository` + the `ExplainPaper` use case, under
      `lib/features/explain/`. The envelope copies `DefaultAnalysisRepository`'s
      (`installation_id` from `InstallationIdProvider`, `app_version`, a fresh
      `session_id` per attempt, `explain_schema_version` from runtime config).
      The repository owns the §33.7 table → `AppFailure` map and the
      `DioException` split. The client timeout is set **longer than the server's
      30 s budget** (§33.8's last rule) and read from runtime config, not
      hard-coded. *Done when:* all twelve §33.7 codes have a test, an HTML
      gateway body is `AnalysisServiceFailure` and not a crash (§31 rule 4),
      offline and too-slow are distinguishable, and **no test or log line
      carries the image or a card** (§7).

- [ ] **T04** `BuildPaperVoiceSegments` — the entity → `List<VoiceSegment>`,
      with the stable id scheme: `explain`, `todo`, `date`, `caution`,
      `contact`, `place`, in that order, one segment **per card** (the approved
      design's status segments are per card, so the 1–4 `explain` paragraphs
      join into one segment). The title opens the `explain` segment's text,
      because §33.3 counts it among the strings the voice reads and the design
      gives it no segment of its own. Null cards produce no segment. *Done
      when:* the ids are asserted as literals (a renamed id silently
      invalidates every stored span), the order is pinned, a paper with only
      the two required cards yields exactly one segment, and the same paper
      yields byte-identical segments on a second call.

### Phase B — the schema and the store

- [ ] **T05** **Schema v4** — the four steps above, in `app_database.dart`, with
      `schemaVersion` 4 and a `_paperSchema` list beside `_documentSchema`.
      *Done when:* a seeded v3 database upgrades with its manual reminders
      intact and **zero** rows left in any of the seven document tables, in
      `reminders` for a linked reminder, or in `reminder_alerts` for its alerts;
      `reminders` has no `document_id` column afterwards (asserted with
      `PRAGMA table_info`, not by compiling); the v1 and v2 migration tests
      still pass; and the FK-off trap above has a test that fails if the deletes
      are left to the cascade.

- [ ] **T06** Cut the reminder ↔ document link in the code (D4). Remove
      `CreateReminderFromDocumentDate`, `ReminderFromDocumentArgs`,
      `ReminderFormCubit.fromDocument`, the `/reminders/create` route, the
      router's `_startReminderFromDate` / `_startReminderFromDocumentDate`, the
      DI registrations, `Reminder.documentId` and the two reminder mappers'
      field, and `reminderCreateScreenTitle` from all three string files.
      `isManual` stays (D5). *Done when:* the old result and details screens
      still build and run with no bell, the manual reminder flow is untouched
      and its own tests unchanged, and the ~8 affected test files are deleted or
      rewritten rather than skipped.

- [ ] **T07** `PapersDao`, `paper_read_mapper`, `paper_write_mapper`,
      `PapersRepository` (interface, `core/papers/`) and
      `DriftPapersRepository`. Reads: `watchPapers()` (the whole list — F41
      splits it), `watchPaper(id)`. Writes: `insertPaper`, `recordReading`,
      `deletePaper`, `deleteAllPapers`. The `eventDay` / `eventMinuteOfDay`
      denormalisation (D7) happens in the write mapper, from the `date` card, so
      it cannot drift from it. *Done when:* a paper with every card round-trips,
      a paper with only the required two round-trips, the paragraphs come back
      in order, the spans come back in order with `exact` intact, deleting a
      paper takes its children **and** its encrypted image and audio, and a row
      whose stored enum no longer parses degrades rather than throwing (the rule
      `document_tables.dart` already states).

- [ ] **T08** `PaperImageStore` + `FilePaperImageStore` →
      `paper_images/{id}/image.enc` (D13). Takes the cropped plaintext path,
      encrypts, deletes the plaintext, answers the stored path. *Done when:*
      round-trip passes, a truncated file yields `FileEncryptionFailure` rather
      than a crash, the plaintext is gone after an `Ok` and **left in place**
      after an `Err`, and a throwing encryptor is classified instead of escaping
      (the `await`-inside-`try` trap F37-T15 names).

- [ ] **T09** The use cases, in `core/papers/usecases/`: `SavePaper` (row +
      photo, D9), `RecordPaperReading` (the `VoiceReadOutcome` and its spans
      onto the row), `WatchPapers`, `WatchPaper`, `DeletePaper`,
      `DeleteAllPapers`, `LoadPaperImage`. *Done when:* the D9 ordering is
      pinned by a test that proves the row exists before any audio id is handed
      out; a `SavePaper` whose image encryption fails still saves the row and
      reports the image's loss separately (the user heard their paper — §3
      forbids losing all of it over the photo); `RecordPaperReading` on a
      device-TTS outcome stores `audioSaved: false` with its spans; and
      `DeleteAllPapers` clears rows, images and audio.

### Phase C — the carry-overs, the wiring and the device

- [ ] **T10** F37's three carry-overs (D12). (a) `==`/`hashCode` on
      `VoiceReadOutcome`, with a test that two equal outcomes compare equal —
      the de-duplication `Cubit` could not do. (b) `GeminiLiveVoiceSession`
      records the socket's **close code and reason** and carries them into
      `VoiceServiceFailure`'s log-code path — **codes and integers only, never a
      frame body** (§7) — so defect 5's next occurrence names itself. (c)
      `AacEncoder` deletes `voice_enc_*.m4a` from `cacheDir` when a read fails
      or is cancelled. *Done when:* (a) and (b) have tests, (b) is asserted to
      log no content, and (c) is verified on the device in T12 (Kotlin holds no
      decisions and is not unit-testable — F37's own rule).

- [ ] **T11** The bootstrap purge step (D14): a `BootstrapStage.cleanup` step
      that deletes the legacy `documents/` directory if present,
      `critical: false`, beside `deleteStaleSessions()`. *Done when:* it removes
      a seeded legacy directory, is a quiet no-op when there is none, is a quiet
      no-op twice in a row, and **cannot touch `paper_images/` or
      `voice_audio/`** — asserted by name, because the one way this step can do
      harm is by deleting the papers it was written to make room for.

- [ ] **T12** DI (`_registerPapers`, `_registerExplain`) beside
      `_registerVoice`; extend `lib/app/dev/voice_harness_screen.dart` with an
      "explain → save → list → replay" path behind the existing `VOICE_HARNESS`
      flag; write `docs/features/F38-device-checklist.md` in F23/F37's style;
      run the full gate. *Done when:* a registration test resolves every pure
      registration for real and asserts the platform-bound ones registered
      (F37-T21's reasoning: a `get_it` registration is a closure, so a missing
      dependency is invisible until something resolves it),
      `voice_harness_guard_test` still proves the harness cannot reach a release
      build, and the device pass on the **RMX2001 (API 30)** covers: a real
      paper explained end to end, the row and both encrypted files on disk,
      **the upgrade wipe over a v3 database that has saved papers with images**,
      offline replay with card highlighting, a device-TTS paper re-speaking on
      replay, delete removing both files, and the measured per-paper disk cost
      written back into D8.

## Files

**`lib/core/papers/`** — `paper_explanation.dart`, `paper_todo.dart`,
`paper_date.dart`, `paper_caution.dart`, `paper_contact.dart`,
`paper_place.dart`, `paper_status.dart`, `saved_paper.dart`,
`papers_repository.dart`, `drift_papers_repository.dart`,
`paper_read_mapper.dart`, `paper_write_mapper.dart`, `paper_image_store.dart`,
`file_paper_image_store.dart`, `build_paper_voice_segments.dart`, `usecases/`
(seven). In `core/` because F39, F40 and F41 all consume them.

**`lib/features/explain/`** — `data/models/explain_request_dto.dart`,
`explain_response_dto.dart`; `data/mappers/explain_response_mapper.dart`;
`data/datasources/explain_remote_data_source.dart`,
`edge_function_explain_remote_data_source.dart`;
`data/repositories/default_explain_repository.dart`;
`domain/repositories/explain_repository.dart`;
`domain/usecases/explain_paper.dart`. The endpoint client has exactly one caller
(F39), so it stays in a feature — the same split that keeps F37's Live client
inside `features/voice/` while its store sits in `core/`.

**`lib/core/database/`** — `tables/paper_tables.dart`, `daos/papers_dao.dart`,
and `app_database.dart`'s v4 migration.

**Changed, not added** — `lib/app/di/service_locator.dart` (two modules, one
bootstrap step, the reminder registrations removed),
`lib/app/router/app_router.dart` (the reminder-create route and both bell
helpers removed), `lib/core/reminders/*` (the `documentId` field),
`lib/core/localization/{app,ar,en}_strings.dart` (one string removed),
`lib/features/voice/data/services/gemini_live_voice_session.dart` (close-code
logging), `lib/features/voice/domain/entities/voice_read_outcome.dart` (`==`),
`android/.../voice/AacEncoder.kt` (temp-file cleanup),
`lib/app/dev/voice_harness_screen.dart` (the new path).

**Docs** — this file, and `docs/features/F38-device-checklist.md`.
`docs/API_CONTRACT.md` is **not** touched: F38 implements §33, it does not amend
it. (And if it ever has to, that file is **CRLF** — never `sed -i` from Git
Bash, which strips CR.)

**No new dependency.** `uuid`, `drift`, `dio` and the crypto stack are all
already here.

## Risks

- **The wipe is irreversible and runs on the owner's parents' phones.** It is
  the owner's decision (F34, answer 1) and the store listing's "what's new" has
  to say so (F44), but F38 is where the data actually dies. The migration test
  seeds a v3 database *with* saved papers and images for exactly this reason,
  and T12 runs it on a real device before anything merges.
- **The denormalised `eventDay`** (D7) can drift from the `date` card if any
  later code writes one without the other. It is written in one place — the
  write mapper — and a test asserts the two agree after a round-trip.
- **Spans are stored against segment ids** (D2/D11). Renaming an id, or changing
  the per-card segmentation, silently invalidates every paper already on every
  device: the audio still plays, and the highlighting lands on the wrong card or
  nowhere. T04 asserts the ids as literals; treat them as a stored format, not
  an implementation detail.
- **D9's ordering means a paper can exist with no audio and no reason recorded.**
  That is the honest state after a crash mid-read, and the user's second open
  re-reads it for free. It also means `audioSaved: false` is not evidence of a
  bug — which is why T10(b)'s close-code logging matters.
- **One read in four still falls to the robotic voice** (F37 defect 5, open and
  accepted). F38 makes it *visible* rather than fixing it: the engine is now
  stored per paper, so the rate can be counted off a real device instead of
  guessed. Do not spend a fix on a guess — F37's note explains what each guess
  trades against.
- **D3 defers a drop.** If F40 and F41 both forget it, the seven legacy tables
  ship empty in 1.1.0. Harmless, but it is a loose end: v5 goes into F41's scope
  fence when that file is written.

## Testing

- **The migration** is the one test that cannot be faked: seed a **v3** schema
  by hand (the way `_versionTwoDatabase()` does), with documents, children,
  images on disk, a linked reminder, that reminder's alert, and a manual
  reminder — then open `AppDatabase` over it and assert what survived.
- **The mapper** is driven by §33.10's worked examples, copied verbatim, plus
  one example per null-card combination that matters.
- **The repository's errors** are table-driven over §33.7's twelve codes, with
  the HTML-body and transport cases alongside them.
- **No real delays.** Use `reading_queue_test.dart`'s `settle()` idiom.
- **The privacy guard is a test, not a review note:** every new entity's
  `toString()`, every new log call and every new error report is asserted to
  carry no word of the page (the guards F37-T03 and F37-T17 already wrote).
- **The device pass finds what tests cannot**
  (`device-pass-finds-what-tests-cannot`, and F37's own five defects behind
  3,235 green tests). T12 is not a formality: the migration, the two encrypted
  stores and the Kotlin cleanup all cross a boundary a fake cannot stand in for.

## Definition of done

12 / 12 tasks DONE with findings recorded inline; the full gate green with
counter lines read; the v3 → v4 migration verified on a device that had saved
papers; one paper explained, auto-saved, replayed offline and deleted on the
RMX2001; the per-paper disk cost measured and written into D8;
`@code-reviewer` passed; and `docs/features/F38-device-checklist.md` filled in
row by row. Then `/explain-feature`, then the PR.
