# F38 · Device Test Checklist (T12)

- **Device:** physical RMX2001 (API 30), over USB with `adb reverse`. Never an
  emulator (`test-on-physical-device-not-emulator`).
- **Build:** `--flavor dev -t lib/main_dev.dart`, branch `feature/paper-model`.
- **Why a device pass at all:** the migration, the two encrypted stores and the
  `AacEncoder` cleanup (T10c) all cross a boundary a fake cannot stand in for
  (`device-pass-finds-what-tests-cannot`, and F37's own five defects behind
  3,235 green tests).

## How to open it — the harness

The same `VOICE_HARNESS` dev screen F37 built, extended here with a "Papers
(F38)" section: a button that picks a photo from the gallery, calls
`explain-document`, saves the result, reads it aloud, and lists every saved
paper with a **Replay** button per row.

```
flutter run -d <RMX2001> --flavor dev -t lib/main_dev.dart \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=VOICE_HARNESS=true
```

The status line under the button prints what is happening in plain English —
`picking photo…`, `explaining…`, `saving…`, `saved <id> … — reading…`,
`recorded reading for <id>` — because this tool exists to show the caller
what the use cases are doing, not to look like a product screen. A paper's
row shows its id, status, voice engine, `audioSaved` and span count — never
its title or paragraphs, the same restraint the state card already keeps for
the voice spine.

**Replay** on a row whose `audioSaved` is `false` does not fail — it re-runs
`readAloud` on the same stored segments (D11: a device-TTS paper re-speaks
rather than replaying a file), and the row's own `RecordPaperReading` call
fires again on completion, exactly as it does for a fresh save.

Two guarantees carried over from F37, re-checked here because this is the
same gated route: `createAppRouter` defaults the harness off, and the one real
caller requires `isDev` **and** the dart-define. `voice_harness_guard_test`
still asserts both.

## 0 · Setup (Claude)

| Step | What | State |
|---|---|---|
| 0.1 | Docker + `supabase start` | |
| 0.2 | `supabase functions serve --env-file supabase/.env` — the local stack serves no Edge Functions without it (`supabase-local-serves-no-functions`), and both `explain-document` and `live-token` are ones | |
| 0.3 | `adb reverse tcp:54321 tcp:54321` | |
| 0.4 | Local DB: `analysis_enabled = true`, `explain_enabled = true` | |
| 0.5 | `GEMINI_API_KEY` present in `supabase/.env` | |
| 0.6 | A **v3** on-device database seeded with at least one saved document (with its encrypted image) and a linked reminder + alert, installed **before** this build's first launch — see scenario A | |
| 0.7 | `flutter run -d <RMX2001> --flavor dev -t lib/main_dev.dart --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=VOICE_HARNESS=true` | |
| 0.8 | Owner: an Arabic TTS voice **installed** on the phone (needed by scenario C) | |

## A · The v3 → v4 migration, on a database that has saved papers

The irreversible one (F38's own Risks section): this runs once, on first
launch over the seeded database from 0.6, and there is no second take on the
same data.

| ID | Do | Expect |
|---|---|---|
| A1 | Launch over the seeded v3 database | The app opens normally — no crash, no stuck splash |
| A2 | Check the app's private storage for the legacy `documents/` directory | **Gone** — both the migration's own wipe and T11's bootstrap purge target it |
| A3 | Open the reminders tab | The manual reminder, if any was seeded, is still there; the one linked to the deleted document is gone, and so is its alert |
| A4 | `adb shell` into the app's database file (or re-run the migration test's own assertions against a pulled copy) | Zero rows in any of the seven legacy document tables, zero in `reminders`/`reminder_alerts` for the deleted link, and `reminders` has no `document_id` column |

## B · Explain → save → read, end to end

**Condition:** everything from §0 up, a clear or mocked photo of any paper
nearby.

| ID | Do | Expect |
|---|---|---|
| B1 | Tap "Pick photo → explain → save → read" and choose a photo | The status line walks through `picking photo…` → `explaining…` → `saving…` → `saved <id> (image: true) — reading…`, then the voice reads the paper aloud |
| B2 | After the read finishes | The status line shows `recorded reading for <id>`, and a new row appears in the list below with that id |
| B3 | Check the app's private storage | `paper_images/<id>/image.enc` and the equivalent encrypted `.m4a` under the voice store both exist |
| B4 | Repeat B1 with a photo of a paper the service cannot make sense of | The row still appears — `status: unsupported` is saved like any other paper (D10) — with no audio file, since there is nothing to read aloud for it |

## C · A device-TTS paper re-speaking on replay

**Condition (Claude):** `explain_enabled = false`, or block the `live-token`
endpoint, so Live cannot be reached and the read falls to the device tier.

| ID | Do | Expect |
|---|---|---|
| C1 | Run B1 under this condition | The paper is read by the phone's own voice; its row shows `engine: deviceTts`, `audioSaved: false` |
| C2 | Tap **Replay** on that row | It speaks again, from the stored card text — not a file, since none was saved. The status line shows `recorded reading for <id>` a second time |

## D · T10(c)'s temp-file cleanup, on the device it was written for

Kotlin holds no decisions and is not unit-testable (F37's own rule), so this
is the one place `AacEncoder`'s fix can actually be checked.

| ID | Do | Expect |
|---|---|---|
| D0a | Start a read, then cut the network a couple of seconds in so the attempt fails before `finish()` | No `voice_enc_*.m4a` is left behind in the app's cache directory afterwards |
| D0b | Start a read, then back out of the harness screen mid-read (cancelling it) | Same — no leftover temp file |

## E · Offline replay with card highlighting

**Condition:** a paper saved under §B with `audioSaved: true` (a Live read).

| ID | Do | Expect |
|---|---|---|
| E1 | Go fully offline (aeroplane mode), then tap **Replay** on that row | It plays from the encrypted file, no network |
| E2 | Watch the state card while it plays | `segment` changes as the reading moves between cards — the stored spans are being used, not re-measured |
| E3 | Seek mid-replay | Works (`canSeek == true` in the file phase), as F37's own D2 already covers — this row only confirms it still holds once the spans come from storage instead of a fresh read |

## F · Delete removes both files

| ID | Do | Expect |
|---|---|---|
| F1 | `getIt<DeletePaper>()(id)` is not reachable from this harness — delete via a Drift inspector or a temporary call, **or** defer this row to F41's first device pass, where مستنداتي's own delete button exists | Both `paper_images/<id>/` and the voice store's `<id>` are gone, and the row disappears from `watchPapers()` |

The harness intentionally has no delete button — this is explicitly a trap to
avoid: deleting someone's papers from a tool with no confirmation. Row F1 may
be waived here and picked up by F41, which is where a real delete control
first exists; if waived, say so in the Results table rather than guessing.

## G · The measured disk cost (D8)

| ID | Do | Expect / Record |
|---|---|---|
| G1 | After a handful of real papers (§B, a mix of Live and device-TTS reads) | `du`/`adb shell du` the app's private storage: `paper_images/` total ÷ paper count, and the voice store's total ÷ paper count with audio |
| G2 | Write the two per-paper averages back into D8 in `F38-paper-model.md` | |

## Results

Run on the RMX2001 (API 30), against the local stack. Fill in after the pass —
every row says what was actually observed; a row not run says so rather than
borrowing a pass from a neighbour.

| ID | ✅ / ❌ | Notes |
|---|---|---|
| A1 | | |
| A2 | | |
| A3 | | |
| A4 | | |
| B1 | | |
| B2 | | |
| B3 | | |
| B4 | | |
| C1 | | |
| C2 | | |
| D0a | | |
| D0b | | |
| E1 | | |
| E2 | | |
| E3 | | |
| F1 | | |
| G1 | | |
| G2 | | |

## What this pass found

Filled in after the device pass, in F37's style: fixed defects, open ones, and
anything D8's measurement changes about the retention question.
