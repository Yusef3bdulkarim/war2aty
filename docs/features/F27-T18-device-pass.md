# F27-T18 · Device pass on real phones

The owner holds the phones and taps; Claude builds, drives `adb`, flips what
has to be flipped on the backend, and records. Every scenario says **who does
what**, **how it is triggered** and **what must be seen**. Mark each row ✅ or
❌ in **Results**, with a note for anything off.

Same shape as [`F23-device-test-checklist.md`](F23-device-test-checklist.md),
which is the precedent for how a device pass is run and recorded here.

## Why this task exists

Everything shipped since P02 — T11's backup rules, T12's monitoring, T13's
release hardening, T15's isolate moves and OS-text-scale change, T16's security
fixes, T17's journeys — is proved by tests, by `aapt2`/`apksigner` on the
artefact, or against a real backend. But **the shipping artefact has been on a
phone exactly once**, at `1.0.0+3`, before all of that landed. A release build
is also the only configuration where R8, resource shrinking and obfuscation can
break a path every debug test passes: the `res/raw/keep.xml` trap in P02 is the
precedent, and it was found on a phone.

T18 also owns three things handed to it on purpose:

- **M6 / F25** — OEM battery-saver handling for scheduled reminders. Reminders
  are `inexactAllowWhileIdle` by decision (F09-T10: no `SCHEDULE_EXACT_ALARM`,
  which Play reserves for alarm-clock apps). Nobody has watched one arrive on a
  phone with realme's or Huawei's battery manager on.
- **F12-T05 (Q7)** — a performance profile on a real device. P01 profiled the
  launch path; T15 fixed two UI-isolate paths statically and recorded that no
  profile was taken on a device.
- **T11's remainder** — the `dataExtractionRules` (device-to-device transfer)
  half, which needs API 31+.

## The build under test

Two builds carry this pass. **`+4`** is what blocks A, B and D were run
against; **`+5`** is the same build with findings D-1 to D-4 fixed, and it is
what the remaining blocks (C, E, F, G) run on.

| | `1.0.0+4` | `1.0.0+5` | `1.0.0+6` |
|---|---|---|---|
| SHA-256 | `7055e68e…2f6ec07c` | `56353490…cb128299` | `13174d33…bf9f0099` |
| Carries | the state at the start of T18 | D-1 copy, D-2 splash fade, D-3 icon re-tint, D-4 high-contrast brand colour | D-1's second half: the banner icon |
| Verified | release cert, 0 fixtures | release cert, 0 fixtures, `versionCode=5`, no `ALLOW_BACKUP` | release cert, 0 fixtures, `versionCode=6` |

`+6` is the build this task closes on, and the one installed on the RMX2001.

| | |
|---|---|
| Version | `1.0.0+4`, then `1.0.0+5` (`versionName 1.0.0`) |
| Artefact | `build/app/outputs/flutter-apk/app-prod-release.apk`, 34.9 MB |
| SHA-256 (`+4`) | `7055e68eac9bd732ee92eed0e25258bee1569eccc5b19f617b5d141f2f6ec07c` |
| Built with | `./tool/build_release.ps1 -Artifact apk -Arm64Only` — prod flavor, `--release`, `--obfuscate`, `--split-debug-info=build/symbols/1.0.0+4`, `--dart-define-from-file=config/prod.json`, `--target-platform android-arm64` |
| Signature | `CN=Yusef Abdulkarim, O=War2aty, L=Cairo, C=EG` — the release key, **not** `CN=Android Debug` (H7) |
| Target / compile SDK | 36 · `native-code: arm64-v8a` only |
| Launcher label | «ورقتي» in every locale (decision #2, T14) |
| Symbols | `build/symbols/1.0.0+4/app.android-arm64.symbols` (5.0 MB) — **keep while this build is installed anywhere** |
| Backend | **production** (`eu-central-1`), `online_ocr_enabled = false` (Q12), `daily_limit = 3`, global cap 500/day |

Artefact checks already done on this machine, before any phone:

- `apksigner verify --print-certs` → the release certificate above.
- Dev mock fixtures: **0** entries (`unzip -l | grep -c fixtures`), as M4 requires.
- `drawable/ic_stat_notify` **survived `isShrinkResources`** — `aapt2 dump
  resources` shows it at mdpi/hdpi/xhdpi. Worth knowing for anyone repeating
  this: a release APK renames resource *files* (`res/67.png`, `res/Jb.png`), so
  grepping the zip listing for the name finds nothing and proves nothing. The
  resource table is the only honest check. Assets (`assets/fixtures/…`) keep
  their paths, which is why the M4 grep in `docs/BUILD.md` still works.
- Gate at this commit: `dart format` 0 changed, `flutter analyze` 0 errors /
  0 warnings (18 infos, the standing baseline), `flutter test` **2,431 passed**.

## 0 · Setup

| Step | Who | What | State |
|---|---|---|---|
| 0.1 | owner | Both phones connected over USB, file transfer on, USB debugging on | |
| 0.2 | Claude | `adb devices -l`, then `getprop ro.product.model`, `ro.build.version.release`, `ro.build.version.sdk`, `ro.build.display.id` for each — **the API levels in this doc are measured, not assumed** | |
| 0.3 | Claude | `pm list packages` filtered for `gms` on the Huawei, to record that it has no Google Mobile Services | |
| 0.4 | owner | **Both phones set to Cairo time** — every date and time the app accepts is read as `Africa/Cairo`, not device-local (`cairo_day.dart`), so a phone on another zone makes every "fire in 2 minutes" target wrong | |
| 0.5 | Claude | `adb install -r` (RMX2001, over `+3`) and `adb install` (ELS-NX9, clean) of the APK above | |
| 0.6 | Claude | `adb logcat -c` before each scenario block, and the relevant tail captured after | |
| 0.7 | Claude | Re-read production's `online_ocr_enabled` and `daily_limit` live before the run — the table above takes them from Q12 and T08's record, and C1–C5 assume on-device reading | |

**Devices** (expected values; 0.2 replaces them with measured ones):

| Device | Expected | Measured |
|---|---|---|
| RMX2001 (realme, realme UI / ColorOS) | Android 11, API 30, arm64 | ✅ **measured 2026-10-07**: `RMX2001` / `RMX2001L1`, brand `realme`, Android **11**, SDK **30**, build `RMX2001_11_C.18`, `arm64-v8a`, density 480 dpi, serial `QCKFXSDAGMCIPB55`. GMS present (3 packages) |
| ELS-NX9 (Huawei P40 Pro 5G, EMUI 12) | Android 10, API 29, arm64, no GMS | **UNREACHED** — not connected for this pass (owner, 2026-10-07). Everything that depends on API 29 or on a GMS-less phone is listed under "Unreached" below |

**Time zone (0.4).** The phone is on `Asia/Riyadh`, not `Africa/Cairo` — but
**both are UTC+3 today**: Egypt is on EEST until late October, confirmed on the
device itself (`TZ=Africa/Cairo date` → `EEST`). So every wall clock picked in
the app matches the phone's own clock for this pass, and no change was needed.
It would stop being true after Egypt leaves DST, which is worth knowing before
the next device session.

This is also live evidence for the DST question raised while planning:
`kCairoUtcOffset` is a fixed `Duration(hours: 2)` while Cairo is **+3** today.

## A · Install and first launch

| ID | Who | Do | Expect |
|---|---|---|---|
| A1 | Claude | RMX2001: install **over** `1.0.0+3` | Installs without uninstalling; `dumpsys package com.war2aty.app` shows `versionCode=4` |
| A1a | Claude | Compare the installed package before and after | What `+3` carried and `+4` does not — see "What the upgrade proved" below |
| A2 | owner | Open it | Previous data is still there: saved papers, reminders and settings survived the upgrade (the Drift migration on real data) |
| A3 | owner | Open a saved paper from before the upgrade | Opens; **its image renders** (T15 moved AES-GCM and the base64 off the UI isolate — this is the path that changed) |
| A4 | Claude | ELS-NX9: clean install | Installs on a phone with no Play Services |
| A5 | owner | First launch | Onboarding, then Home; «تحليلاتك النهارده» shows the real remaining count (an anonymous identity was created and `get-usage` answered) |
| A6 | owner | Both: look at the launcher | The P01 icon, sharp; «ورقتي» under it; the Huawei's and realme's own icon masks do not crop the mark |
| A7 | owner | Both: themed / monochrome icon, if the launcher offers it | The monochrome layer is used, not a white square |
| A8 | owner | Both: watch the launch | Teal splash → the mark and rings → it **settles**, then Home appears; no white flash, no cut, no frozen rings |
| A9 | Claude | Both: `dumpsys package` flags | **No `ALLOW_BACKUP`** (T11, now on the shipping package) |

### What the upgrade proved (A1, A1a, A9 — Claude, 2026-10-07)

`1.0.0+3` was still on the phone from P02 (2026-10-05), built **before** T11 and
T16. So the upgrade is a before/after on the same device, on the **prod**
package — which is stronger than either task could manage at the time: T11 ran
its live check on the `.dev` package, and T16's permission removal was proved on
the APK with `aapt2`, never on a phone.

| | `1.0.0+3` (P02) | `1.0.0+4` (this build) |
|---|---|---|
| `flags=` | `[ HAS_CODE ALLOW_CLEAR_USER_DATA `**`ALLOW_BACKUP`**` ]` | `[ HAS_CODE ALLOW_CLEAR_USER_DATA ]` |
| `RECORD_AUDIO` | requested | **absent** |
| `READ_EXTERNAL_STORAGE` | requested | **absent** |
| `bmgr backupnow com.war2aty.app` | (T11 measured «Size quota exceeded» — Android *attempted* it) | «**Backup is not allowed**» |

- `versionCode=4`, `firstInstallTime` unchanged at `2026-10-05 06:46:05`, so this
  was a real upgrade over real data, not a reinstall.
- The backup refusal was taken with the owner's **own Google transport still
  selected** — `allowBackup="false"` makes the package ineligible whatever the
  transport, so nothing had to be switched and nothing could have been uploaded.
  The transport was verified unchanged afterwards.
- The full requested-permission set of the shipping build is now:
  `CAMERA`, `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
  `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `VIBRATE`, and the Flutter
  `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. The last three come from plugins
  (connectivity, local notifications, the engine) and are benign — recorded here
  for T19's permission review, which is the task that owns the Play listing.

## B · The paper journey, once per phone, against production

One real paper each (an electricity bill if there is one). This spends 2 of
production's 500/day.

| ID | Who | Do | Expect |
|---|---|---|---|
| B1 | owner | Home → camera | Preview opens; the live edge detector finds the paper's edges on a normal desk |
| B2 | owner | Shutter, then adjust the crop | The crop handles work; their screen-reader labels are in the app's language (T15 fixed four hardcoded Arabic ones) |
| B3 | owner | Continue | The reading step runs **on the phone** (Tesseract, because `online_ocr_enabled` is off) and the review screen shows the text |
| B4 | owner | Continue | The wait screen runs, then the explanation arrives from production |
| B5 | owner | Read the result | Type, summary, what is required, dates — nothing empty, nothing in English in the Arabic UI |
| B6 | owner | Tap listen | TTS reads in Arabic; pause and resume work |
| B7 | owner | Save, choosing «النتيجة فقط» | Saved, and **no image** is kept (T17 proved this in a test; here it is the real thing) |
| B8 | owner | Save another with the image | The image is kept and reopens |
| B9 | owner | Create a reminder from a date on the paper | The reminder is created and the success screen appears |
| B10 | owner | Home | The remaining-analyses count went down by exactly the number of analyses run |
| B11 | Claude | After both phones: read `error_reports` on production for this window | Only allowlisted codes, **no document content, no stack traces** (T12, §7) |

## C · Failure paths reachable without touching production

| ID | Who | Do | Expect |
|---|---|---|---|
| C1 | owner | Airplane mode on, then photograph a paper and continue | The F23 «النت فاصل دلوقتي» page: the text was still read on the phone, the tracker shows the first two steps green and the third waiting |
| C2 | owner | Airplane mode off, tap «حاول تاني» | The explanation arrives **without photographing again** |
| C3 | owner | Use up the day's three analyses on one phone | The «خلّصت تحليلات النهارده» page with its countdown to midnight Cairo, and «استخدمت 3 من 3 النهارده» |
| C4 | owner | Settings → turn «السماح بإرسال النص للتحليل» off, then analyse | The «الشرح الذكي مقفول» page; turn it back on afterwards |
| C5 | owner | Photograph something that is not a paper | The «مقدرناش نشرح الورقة دي» page, and the attempt **was not counted** |

**Q1 answered 2026-10-07 — (b), no staging pass.** The online reading route,
the F20 §1 fallback banner and the kill-switch failure pages are therefore
**never exercised in a release build on real hardware before launch**. That is
a deliberate trade, not an oversight, and it lands on **T26**: the flag flip
there will put every user on a path whose only evidence is the integration
suite (F27-T17, which fakes the network edge) and the local/live backend checks
of T05 and T08. T26 already inherits the unprotected-OCR risk from T06; this
joins it, and both belong in the same conversation before the flag moves.

## D · Languages, accessibility and settings, in the release build

| ID | Who | Do | Expect |
|---|---|---|---|
| D1 | owner | Switch the app to English | Everything English and mirrored; the chevrons point **forward** (T15 fixed four that pointed backwards) |
| D2 | owner | Android's own font size to maximum, app text size at default | The app follows the OS size, capped at ×2.0 (T15); nothing is cut off on Home, the result page or the reminder screens |
| D3 | owner | App text size to maximum as well | Still capped at ×2.0; the in-app control looks inert at that point, which is known and recorded |
| D4 | owner | «تباين عالي» on | Readable everywhere |
| D5 | owner | TalkBack on, over Home → result → reminder | Headings read as headings, the tracker as one sentence, buttons as buttons |
| D6 | owner | Settings → «الأذونات والتنبيهات» | Camera and notification statuses are right; «فتح إعدادات الإشعارات» opens the OS page |
| D7 | owner | Privacy screen | The §7 wording, with no provider named and no claim that nobody sees the image or the text |

## E · Reminders and OEM battery savers — the headline (M6)

**How to make an alert fire in minutes.** Reminders tab → add
(`/reminders/manual`) → title, today's date, a time a few minutes ahead. A
manual reminder seeds one alert at the event time, and the pickers have no
"must be far in the future" guard. To retarget an existing reminder, snooze it
and choose «اختيار وقت جديد». Remember 0.4: the time you pick is **Cairo** time.

**Evidence for every row** (Claude): `adb shell dumpsys alarm` filtered for the
package, before and after; the scheduled time; the time the notification
actually appeared; the logcat tail. The distinction that matters is **late**
versus **never**: `inexactAllowWhileIdle` is allowed to slip by minutes, and
for a day-scale reminder that is fine. Dropped is a finding.

| ID | Case | How | What it decides |
|---|---|---|---|
| E1 | App in the foreground | — | baseline |
| E2 | Backgrounded, screen off | — | baseline |
| E3 | Swiped out of recents | — | the alarm survives task removal |
| E4 | Doze | `adb shell dumpsys deviceidle force-idle` | that `inexactAllowWhileIdle` fires under Doze, and how late |
| E5 | System battery saver on | OS setting | late vs never |
| E6 | **OEM restriction on** — realme: battery optimisation / auto-launch off; Huawei: "App launch → manage manually" off | per OEM | **the task's real question** |
| E7 | Reboot with a pending reminder | reboot, then `dumpsys alarm` | the boot receiver re-arms it — and whether the OEM blocks it |
| E8 | `adb shell am force-stop`, then reopen the app | | Android drops alarms on force-stop; whether `ReminderScheduler.reconcile` brings them back |
| E9 | Notifications (or just the «التذكيرات» channel) switched off | OS settings | what the user is told — the nearest reachable stand-in for the API 33 prompt |
| E10 | Tap the notification: app killed, backgrounded, foreground | | each lands on that reminder's details |
| E11 | Tap a notification whose reminder was deleted first | F23 G4 | the «not found» state, no crash |
| E12 | A note longer than one line, and hidden-details mode | F25 checklist 1–2, 5 | the body expands; hidden mode shows «… عندك تذكير {title}» and no note |
| E13 | Both phones | | the notification's small icon is **the mark**, not a white square (the `ic_stat_notify` shrink trap) |
| E14 | Both phones | | the reminder arrives as a **banner**, not silently into the shade — see candidate 1 below |

### What to watch for, with the fix shape already known

Read out of the scheduling path while preparing this pass. Each is a defect
only a phone can confirm:

1. **The channel is created with no `importance`**, so it is
   `defaultImportance` — sound, but **no heads-up banner**
   (`flutter_local_notifications_port.dart`). On EMUI and realme UI a reminder
   that only lands in the shade is what a user calls "it never arrived". The
   fix has a trap: Android will not let an app *raise* an existing channel's
   importance, so it needs a new channel id and the old one deleted.
2. **`reconcile()` runs on cold start only** (`service_locator.dart`,
   post-splash, `critical: false`). A process resumed for weeks never re-arms
   anything an OEM dropped. Candidate fix: reconcile on resume.
3. **`ReminderAlertStatus.failed` is written and never shown.** A reconcile
   that failed to arm an alarm is invisible to the user — against CLAUDE.md §3.
4. **A denied notification permission never blocks a save and warns nobody
   afterwards** (`reminder_form_cubit.dart`); only the settings row says
   anything. E9 is where that shows.

## F · Performance profile (F12-T05, T15's residual)

Profile build, **not** the release APK — DevTools cannot attach to a release
build:

```
flutter run --profile --flavor prod -t lib/main_prod.dart --dart-define-from-file=config/prod.json
```

(The T13 key check fires only on prod *release* tasks, so this builds.) On the
RMX2001 first, as the slower phone. Every number is recorded with build mode,
flavor, device and refresh rate beside it, the way P01's were.

| ID | Path | Method | Target |
|---|---|---|---|
| F1 | Launch to Home | `--trace-startup` | no regression against P01's numbers |
| F2 | Splash → Home hand-off | DevTools timeline | no dropped frame at the reveal |
| F3 | Camera preview with live edge detection | `dumpsys gfxinfo` framestats | the F16 perf guard behaves in the field |
| F4 | Crop screen interaction | timeline | — |
| F5 | The F22 wait screen, a full run | timeline | no dropped frames (pending **Q2**: this is also F22-T09) |
| F6 | Result page scroll, saved-papers list scroll | framestats | — |
| F7 | **Open a saved paper** | timeline | the decrypt and base64 no longer block the UI isolate (T15's change, measured) |
| F8 | The online request body | timeline | only if Q1 adds the staging pass — T15 recorded that Dio still serialises a ~5 MB string on the calling isolate |

## G · Regression rows never run (F23 §G)

| ID | Do | Expect |
|---|---|---|
| G1 | A normal successful analysis | The result page's teal bar and hero look right |
| G2 | Open a saved paper | Its bar and ⋮ menu work |
| G3 | The wait screen before a failure | The magnifier runs, the failure page replaces it at once |

**Q2 answered 2026-10-07 — (b).** Folded in: **F22-T09** (the wait screen's
own device pass, still TODO in F22 — smoothness, TalkBack, the haptic, ×2 text,
a full run) as part of F5, and **F16-T10's three paper cases** below. Left out
deliberately: F16-T10's battery-drain-off-charge measurement, which takes hours
and has no launch decision hanging on it — it stays open in F16.

| ID | Do | Expect |
|---|---|---|
| G4 | Photograph a paper in **low light** | The edge detector finds it, or fails visibly rather than cropping wrongly; the reading is still usable |
| G5 | Photograph a **receipt** (long, narrow, thermal) | Detected and cropped as a receipt, not as a page |
| G6 | Photograph a page with a **coloured border** | The border is not mistaken for the page edge |

## Results

Filled in during the run. One row per scenario block per phone.

| ID | RMX2001 | ELS-NX9 | Notes |
|---|---|---|---|
| A1, A1a, A9 | ✅ | — | Claude, 2026-10-07: upgrade over `+3`, `ALLOW_BACKUP` gone, backup refused, `RECORD_AUDIO` / `READ_EXTERNAL_STORAGE` gone |
| A2, A3 | ✅ | — | Owner, 2026-10-07: old data preserved; a saved paper's image renders |
| A6, A7 | ⚠️ | — | Owner: icon sharp and well fitted, but **its teal is not the brand teal** → **D-3** |
| A8 | ⚠️ | — | Owner: no white flash, no cut, no frozen rings — but **~1 s of flat teal before the mark** → **D-2** (root-caused, by design) |
| B1–B10 | ⚠️ | — | Owner: the whole journey works; reading ran **on the device**, confirming `online_ocr_enabled = false` on production by behaviour (step 0.7). But the review screen claimed the reading was poor **because there was no internet**, while online → **D-1** |
| B11 | ⬜ | — | not run — closed before the backend read-back |
| C1–C5 | ⬜ | — | **not run** — approved, then closed before execution |
| D1, D2, D5–D7 | ✅ | — | Owner: Arabic and English both fine; the rest of the section fine |
| D4 | ⚠️ | — | Owner: high contrast works, but **the brand colour should not change** → **D-4** |
| E1–E14 | ⬜ | — | **not run** — this was the task's headline (M6); see "Closed early" |
| F1–F8 | ⬜ | — | **not run** — F12-T05's device profile, and F22-T09 with it |
| G1–G6 | ⬜ | — | **not run** (G4–G6 are F16-T10's, folded in per Q2) |

Legend: ✅ passed · ⚠️ passed with a finding · ❌ failed · ⬜ not run.
A4, A5 and the whole ELS-NX9 column are **unreached** (see below).

## Findings

Each classified **blocking launch** / **fix now** / **owner's call** / **record
and accept**; each fix carries a test that reproduces it.

### D-1 · «القراءة تمت بدون إنترنت» is shown to users who have internet — **FIXED** (copy in `+5`, icon in `+6`)

Reported by the owner from B: the review screen said the reading might be less
accurate *because it was done without internet*, on a phone that was online —
the analysis that followed reached production over the same connection.

The copy is not merely clumsy, it is **false, and it will be shown to every
user at launch**. `DecideAnalysisRoute`
([`decide_analysis_route.dart`](../../lib/features/capture/domain/usecases/decide_analysis_route.dart))
returns `AnalysisRoute.offline` for **three** different reasons:

1. no connectivity;
2. the server's `online_ocr_enabled` is **false** — which is the launch state
   by Q12, i.e. the normal path for every user until T26 flips it;
3. the flag could not be read (fails closed, by design).

`OcrReviewCubit.loadOffline` maps all three to `OcrReadMode.offline`
([`ocr_review_cubit.dart:201`](../../lib/features/analysis/presentation/cubit/ocr_review_cubit.dart#L201)),
and the review screen renders one banner for it
([`ocr_review_screen.dart:334`](../../lib/features/analysis/presentation/screens/ocr_review_screen.dart#L334)):
`ocrOfflineQualityWarning` = «النتيجة ممكن تكون أقل دقة لأن القراءة تمت بدون
إنترنت». Reason 2 is the one in production today, so the app currently tells
**100 % of users** that their internet was down when it was not.

Two fix shapes, owner's choice on copy:

- **(a) Reason-neutral copy, one string, no new state.** Something true in all
  three cases: the page was read on the phone, so the text may be less
  accurate — check it. Then guard it the way §7 copy is guarded: assert the
  string never claims a connection problem.
- **(b) Carry the reason** (`offlineReason: noConnection | onlineReadingOff`)
  from `DecideAnalysisRoute` through to the banner and show two texts.

**Done (owner approved (a), 2026-10-07):** the banner now says *where* the
page was read and never *why* — ar «قرينا الورقة على موبايلك، فالنتيجة ممكن
تكون أقل دقة — راجع النص كويس», en "We read the paper on your phone, so results
may be less accurate — check the text". `AppStrings`' doc comment now carries
the rule, next to the sibling that already had it.

Guarded by four new tests in `app_strings_test`: the Arabic copy must not blame
the connection, the English copy must not, the explicit-fallback banner must
still name the online reading (true in its one case), and **the guard itself is
proved against the wording it replaced**. That last one exists because the first
version of this guard was wrong in an instructive way: «فالنتيجة» (the result)
*contains* «النت» (the net), so a plain substring check failed on honest copy.
The banned terms are regexes now, with «النت» matched only as a whole word.

The sibling banner (`ocrOnlineFallbackWarning`) was **not** touched: its cause
really is that the online reading was unavailable, so it may say so.

**Second half, caught by the owner on `+5`: the icon still blamed the
connection.** The words had changed; `_OfflineWarning`'s default icon was still
`Icons.wifi_off`, and an icon is read before any text is. It is now
`Icons.smartphone` — which is what is actually true of all three on-device
routes: the page was read here. Guarded by a test that asserts **no**
connectivity icon (`wifi_off`, `signal_wifi_off`, `cloud_off`,
`signal_wifi_connected_no_internet_4`) appears on that banner, so the next
person to reach for one has to argue with a test rather than with nobody.

### D-2 · About a second of flat teal before the mark — **FIXED in `+5`** (was by design)

The owner asked for a root cause. Measured on this phone, release build:

| Moment | When | Why |
|---|---|---|
| System starting window appears — **flat teal, no mark** | ~100 ms | `launch_background.xml` is a single `@color/splash_bg` item, and `values-v31` sets a transparent `splash_icon`. P01 chose this deliberately so the mark would appear **once**, in the Flutter animation |
| App's first frame (`am start -W` TotalTime) | **~440 ms** (5 runs: 422, 437, 438, 442, 677) | engine + Dart VM + framework init. For a Flutter app this *is* Flutter's first frame — and it too is plain teal, because the mark's opacity at entrance t=0 is 0 |
| Entrance starts | +2 frames (~33 ms) | deliberate (P01): the first frame is the costliest (~210 ms measured then), so the stall lands on a still screen instead of jumping the mark |
| Mark fades in | **0.10 s → 0.75 s of the 1.8 s entrance** (the screen's own doc comment) | so it starts showing at ~570 ms and is fully opaque at ~1,220 ms |

So the flat-teal stretch is ≈ **0.6–0.9 s** before the mark reads as present,
and ~1.2 s before it is solid. **Nothing is slow and nothing is broken**: 440 ms
to first frame on a 2020 mid-range phone in a release build is a good number.
The perception comes from two deliberate choices stacked on top of each other —
a mark-free native splash, and a 650 ms fade.

Levers, cheapest first:

- **(a) Bring the mark's fade forward** (e.g. 0.00 → 0.30 s instead of
  0.10 → 0.75 s). Pure Dart, reversible, already covered by tests, no native
  risk. Removes most of the perceived gap. The 2-frame delay stays.
- **(b) Put a static mark in the native splash** (`launch_background.xml`, and
  `windowSplashScreenAnimatedIcon` on API 31+) and start the Flutter mark at
  full opacity so the layers line up. The mark would be on screen from ~100 ms.
  This is what P01 deliberately avoided: any mismatch in size or position
  between the native bitmap and the Flutter mark shows as a jump, and on
  Android 12+ the system splash sizes its icon by its own rules. Needs the
  owner's eyes on a device.
- **(c) Cut time-to-first-frame.** P01 already moved tzdata off the UI isolate
  and pre-decoded the mark; what is left is engine and plugin registration, and
  it is the smaller half of the gap.

**The splash gets its own task (owner, 2026-10-07).** What T18 shipped stays
and the owner confirmed it reads correctly on the phone, but the rest of the
launch look — including whether the native splash should carry the mark at all,
which is option (b) above and a design decision — is deliberately **not** being
decided inside a device-pass task. A dedicated splash feature follows once T18
is closed.

**Done in T18 (owner approved (a), 2026-10-07):** the mark's fade is now
`_span(0, 0.30)` instead of `_span(0.10, 0.75)`, so it is solid about 450 ms
earlier. The two-frame delay before the entrance **stays** — it is what keeps
the first frame's cost off a moving mark — and the entrance, the hold and the
hand-off are otherwise untouched, so total launch time is unchanged.

Three tests cover it: the two that pinned the old timing now sample the fade at
150 ms and settled at ~310 ms, and a new one asserts the mark is fully opaque
within 320 ms of the entrance. Restoring the old curve fails that test, which is
the regression it exists for.

How it was measured, for anyone repeating it: `screenrecord` is not available to
the shell on this ColorOS build, and `dumpsys gfxinfo` cannot see Flutter frames
at all (it reports the View/HWUI side — 7 views, 2 frames — while Flutter renders
into its own `SurfaceView` layer). The usable instruments were `am start -W`
and `dumpsys SurfaceFlinger --latency "SurfaceView - com.war2aty.app/…"`, whose
frame timestamps confirmed continuous 60 Hz rendering from the first frame.
Note that SurfaceFlinger's clock is `CLOCK_MONOTONIC` while `/proc/uptime` is
boot time — on this phone they differ by ~46 h of suspend, which makes naive
anchoring between them meaningless.

### D-3 · The icon's teal is not the brand teal — **FIXED in `+5`**

The owner reports the launcher icon looks right but its colour does not match
the app's main colour. It does not: P01 lifted the icon out of the owner's
mockup, so its background is the mockup's own gradient (about `#035763` →
`#023742`), while the brand is `#0E7C86` / deep `#0A5C64`. The icon is therefore
darker and greener than every teal surface in the app.

**Done (owner approved, 2026-10-07), and the scope decision was explicitly
left to me: re-tint the icon, do not touch the app palette.** The palette is
the approved design source (`Waraqti.dc.html`) and reaches every screen and
test baseline; the icon is one generator and its output. Re-colouring the
design system to match a mockup-derived icon would have been the tail wagging
the dog.

`_retintToBrand` in `tool/branding/generate_brand_assets.dart` maps the
extracted field onto the brand ramp **by luminance** rather than replacing it
with a flat gradient, so the mockup's vertical falloff and the soft glow behind
the symbol survive and only the hue and depth move: darkest pixel →
`#0A5C64`, brightest → `#0E7C86`, the same pair the Flutter splash paints a
moment later. The symbol is still lifted off the **original** field, because
colour-to-alpha only works against the background the artwork was actually
drawn on — so the mockup's teal is kept for that and re-tinted afterwards.

Every density, the adaptive background, the round and legacy icons, the iOS set
and `assets/app_icon.png` were regenerated. The dev flavor's amber is untouched.
`build/branding-preview/6_brand_retint_before_after.png` shows the old tile, the
new one and the splash gradient side by side; `1_launcher_sizes.png` confirms it
still reads at 36–192 dp on light and dark wallpaper. The network's thin lines
still blur at the smallest sizes — P01 flagged that and the re-tint neither
helps nor hurts it.

### D-4 · High contrast should keep the brand colour — **FIXED in `+5`**

The owner wants `brandPrimary` to stay as it is when «تباين عالي» is on. Today
the high-contrast palette swaps it for the deep teal
([`app_colors.dart:184`](../../lib/core/theme/app_colors.dart#L184):
`#0A5C64` instead of `#0E7C86`).

Measured contrast ratios, so the decision is made on numbers rather than taste:

| Pair | `#0E7C86` (brand) | `#0A5C64` (today's high contrast) |
|---|---|---|
| on white — buttons, brand text on `bgBase` | **4.95 : 1** — passes AA for normal text | 7.70 : 1 |
| on the teal card surface — brand text on a tint | **4.28 : 1** here (and **4.45 : 1** in light, whose `surfaceTeal` is lighter) — passes AA for *large* text, just under the 4.5 for small | 6.66 : 1 |

So keeping the brand colour is safe everywhere it sits on white, and slips
slightly under AA only for **small** brand-coloured text on the pale teal
surfaces. **Done (owner approved, 2026-10-07):** `AppColors.highContrast.brandPrimary`
is now `#0E7C86`, identical to `light`. `brandDeep` was deliberately left at
`#063E44`: it is the far end of gradients and pressed states, never the brand's
own colour, so the decision does not reach it.

**Corrected after `@code-reviewer`, 2026-10-07.** Two statements made here
earlier were wrong, and the guard that was supposed to hold them was worse:

- I wrote that the light palette "already reads exactly" 4.28:1 for this pair.
  It does not. Light reads **4.45:1**, high contrast **4.28:1**, because the two
  palettes do **not** share `surfaceTeal` (`#EEF4F5` in light, `#E4F1F2` here).
- The test asserting "the same in both palettes" fed `highContrast.surfaceTeal`
  to **both** sides, so it compared a value with itself. The review caught the
  tautology; checking it turned up the wrong surface underneath.

What is actually true, and now pinned to the measured numbers: this pair misses
AA for small text in **both** palettes (4.45 light, 4.28 here), so D-4 gives up
a lift high contrast used to provide rather than opening a new gap — and the
test now asserts both ratios, that high contrast reads *lower* than light (if
that ever inverts, one of the surfaces moved), and a 4.2 floor. The
`onBrand`-on-`brandPrimary` AA assertion still passes at 4.95:1.

## Review

`/flutter-code-review` ran on the working tree, and `@code-reviewer` on the
commit: **PASS — no blocking or major findings.** Both of its minor items were
real and both are fixed:

1. The high-contrast contrast test was **tautological** — it compared the same
   value with itself. Fixing it exposed that the claim beside it was also wrong;
   see D-4 above.
2. The Arabic word-boundary lookahead covered letters (U+0621–U+064A) but not
   tashkeel, so a vowelled «النتُ» could have slipped past. The class now runs
   to U+0652.

It independently confirmed the things most worth confirming: the new copy and
icon are truthful in **all three** on-device cases and in the online-fallback
case; the faster fade breaks no timing assumption in `SplashHandOff`, the
breath, the settle, the exit or reduced motion, because `kLogoEntranceDuration`
and the completion callback are untouched; `_retintToBrand` is order-correct
(the symbol is lifted against the original field) and safe at zero span; and the
icon swap costs nothing in RTL or Large Text.

## Closed early — owner's decision, 2026-10-07

The owner closed T18 after the A, B and D blocks and the four fixes, before the
remaining blocks ran. That is their call to make, and this section exists so the
difference between "passed" and "not attempted" survives the task being marked
DONE.

### What this task actually proved

- The **shipping artefact runs on real hardware** at `1.0.0+6`: it installs over
  the previous build, keeps real data through the Drift migration, launches,
  photographs, reads on the device, analyses against production, speaks, saves,
  and creates a reminder — all in a release build with R8, resource shrinking
  and obfuscation on. That is the thing no test can do.
- **T11 and T16 are now true of the shipping package on a phone**, not only of
  the APK: `ALLOW_BACKUP` gone, a backup actually refused by the system, and
  `RECORD_AUDIO` / `READ_EXTERNAL_STORAGE` absent where `+3` had them.
- **Four defects were found by looking at a phone**, three of which no test in
  this repo could have caught, and all four are fixed with guards: D-1 (copy
  **and** icon), D-2, D-3, D-4.
- The production flag state (`online_ocr_enabled = false`) was confirmed **by
  behaviour**, which is better evidence than reading the table.

### What was not attempted, and where it goes

| Not run | What it was for | Where it now sits |
|---|---|---|
| **E1–E14 — reminders under OEM battery savers** | **M6**, deferred from F25 to here. The whole point was to learn whether a reminder under realme's battery manager is *late* or *never*. | **Still unverified on any phone.** Needs a home: a later device session, or T26's pre-flight. The owner assigns it |
| **F1–F8 — performance profile on a device** | **F12-T05** (Q7), plus T15's two recorded residuals and **F22-T09** folded in at Q2 | unmeasured; F22-T09 stays TODO in F22 |
| C1–C5 — failure paths in a release build | the F23 pages on real hardware | unexercised in a release build |
| G1–G6 — regressions + F16-T10's three paper cases | folded in at Q2 | F16-T10 stays PARTIAL |
| B11 — `error_reports` read-back | confirming no document content left the device | not done; the T12 guards still stand on their own tests |
| A4, A5 — a clean first install | onboarding, fresh identity, first `get-usage` | only the upgrade path was exercised |
| The whole ELS-NX9 column | a second OEM, a GMS-less phone | see "Unreached" below |

**One live observation worth keeping**, found while preparing the E block and
never followed up: immediately after `adb install -r`, `dumpsys alarm` showed
**no pending alarm** for the app, although a reminder had been created minutes
earlier. Android does cancel a replaced package's alarms — that is expected —
but the app declares `MY_PACKAGE_REPLACED` on
`ScheduledNotificationBootReceiver` exactly so the plugin re-arms them, and on
this phone nothing was re-armed. Whether `reconcile()` recovers it at the next
cold start was the next step and was not taken. It is a single observation, not
a finding: it has no second run behind it, and the app had not been launched
since the update. Anyone picking up M6 should start here.

## Unreached — the second phone (ELS-NX9), owner's call 2026-10-07

The owner connected the RMX2001 only and asked for this pass to run on it
alone, with everything the Huawei would have covered recorded as unreached
rather than quietly dropped. None of these is a finding; each is a gap with a
named owner.

| # | What it would have shown | Why only that phone | Carried to |
|---|---|---|---|
| U1 | **The app on a phone with no Google Mobile Services** — anonymous sign-in, `get-usage`, the analysis call, local notifications and TTS all working with no Play Services present. The RMX2001 has GMS (3 packages), so this pass cannot distinguish "works" from "works because GMS is there". | The ELS-NX9 is the only GMS-less device | a later device session; **T22** cannot use that phone at all (no Play Store) |
| U2 | **A second OEM's battery manager** — EMUI's "App launch → manage manually" and PowerGenie are more aggressive than realme's, and the E-block result on one OEM does not generalise | — | the E-block's conclusion is explicitly single-OEM |
| U3 | **Android 10 / API 29 behaviour** — one API level below this pass, including the uncapped `READ_EXTERNAL_STORAGE` window T16 closed (API 29–32 is exactly where the derived permission was live) | — | the removal is proved on API 30 here and by `aapt2` on the artefact |
| U4 | **A clean first install** (A4, A5): onboarding, a fresh anonymous identity, the first `get-usage`. This pass installed **over** `+3`, so it proves the upgrade path instead | the RMX2001 could do a clean install only by losing the owner's data | a later session, or a clean install on this phone if the owner accepts the data loss |
| U5 | **A second screen geometry** (density, aspect ratio, notch) against the T15 audit, which was sized for a 360×640 phone | — | later |

## What no available phone can cover

Recorded here rather than assumed, because the owner's rule is that no emulator
stands in for a device:

1. **T11's device-to-device transfer check** (`dataExtractionRules`) needs API
   31+. Both phones are below it. The setting is already verified three ways
   short of a device — the compiled resource in the APK, the merged manifest,
   and a 6-test guard.
2. **The Android 13+ `POST_NOTIFICATIONS` runtime prompt** (F09-T09) cannot
   appear on API ≤32, where notifications are on by default. E9 switches the
   permission off by hand instead, which is the nearest reachable equivalent.
3. **Android 14, 15 and 16 behaviour**, although the app targets **SDK 36**:
   the newer background, alarm and notification restrictions, and Play's 16 KB
   page-size requirement (T19 checks that one on the artefact, not on a phone).

Each of these belongs to T19, T21 or T26 — whichever first has a device that
can reach it.
