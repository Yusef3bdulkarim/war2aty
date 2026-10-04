# F25 · Reminder notifications

- **Branch:** `feature/reminder-notifications`, based on `develop` · **Milestone:** post-F24
- **Depends on:** F09 (reminders, `ReminderScheduler`, the notification port), F11-T10 (the notification-privacy setting)
- **Progress:** 6 / 7 DONE (T03 and T05 reverted by T07)

What a reminder's OS notification says, and what the user can do from it.
F09 shipped a bare notification: hidden mode (the default) said only «عندك
تذكير بموعد قريب», revealed mode showed the reminder's title and the user's
note, nothing said *when*, and tapping it just opened the app.

## Locked decisions

Resolved with the owner on 2026-10-03, from four proposed copy styles.

1. **Style D — the tone rises as the event gets closer.** One stage per
   alert, worked out when the alert is scheduled from the alert's own instant
   and the event (Cairo calendar days, then hours on the event's own day):

   | Stage | Title (details shown) | Body (details shown) | Title (hidden) |
   |---|---|---|---|
   | 2+ days away | فاضل 3 أيام: {title} | الموعد 15 أكتوبر الساعة 10:00 صباحًا. | عندك موعد بعد 3 أيام |
   | The day before | بكرة آخر ميعاد: {title} | الساعة 10:00 صباحًا. | عندك موعد بكرة |
   | Same day, hours away | بعد ساعتين: {title} | الساعة 10:00 صباحًا. | عندك موعد بعد ساعتين |
   | Same day, no event time | النهارده: {title} | — | عندك موعد النهارده |
   | At (or past) the event | دلوقتي: {title} | ميعادها جه. | عندك موعد دلوقتي |

   Hidden mode's body is always «افتح التطبيق علشان تشوف التفاصيل.»
2. **Hidden mode may say *when*** («بكرة», «بعد ساعتين») — never the
   reminder's title, note, amounts or numbers from the paper.
3. **No emoji.**
4. **The user's note is appended to the body** whenever details are shown.
5. **Tapping the notification opens that reminder's details screen.**
6. ~~Two action buttons: «تم» (complete) and «أجّل ساعة» (snooze one hour),
   handled without opening the app.~~ **Withdrawn 2026-10-04** — see
   *Revision* below.
7. **English mirrors all of it** in `EnStrings`.

## Revision — 2026-10-04: no notification buttons (Option 3)

A risk review before any PR or device test found that running the buttons
without opening the app (T05) could not be made reliable:

- **iOS** — the plugin tells iOS the action is handled before any Dart code
  runs, so iOS may suspend the app mid-write.
- **Android** — the plugin's receiver does not keep the process alive while
  the work runs, and Android 14's freezer and OEM battery savers (Xiaomi,
  Huawei, Oppo, Samsung) can stop it.
- **Silent failure** — the notification was dismissed before the work ran, so
  a failed press left no trace.
- **App-wide blast radius** — sharing the Drift database across isolates
  changed how every screen reaches the database.

The owner chose to **remove the buttons entirely** and keep tap-to-open: the
details screen already offers «تم التنفيذ» and «تأجيل». T07 removed the
buttons, `HandleReminderNotificationAction`, the background entry point, the
Android `ActionBroadcastReceiver`, the iOS plugin registrant callback, and the
shared-isolate database option — `app_database.dart`, `AndroidManifest.xml`
and `AppDelegate.swift` are byte-identical to `develop` again.

Kept as approved: decision #2 (hidden mode says when). **Deferred to a
separate feature after F25:** OEM battery restrictions on scheduled alarms
(a risk F09 already had; F25 does not add to it).

Derived, not in the owner's table: «النهارده» for an event with no time
whose alert is on the event day, and «دلوقتي» also covers an alert that fires
after the event (a snoozed overdue reminder). Times and digits use the app's
existing formatters (`formatWallClockTime`, Western digits) so a notification
reads the same as the reminder details screen.

## Tasks

| # | ID | Task | Output | Status |
|---|---|---|---|---|
| 1 | F25-T01 | Escalating copy | `reminderNotificationContent` per alert; ar/en strings; scheduler passes the alert | DONE |
| 2 | F25-T02 | Port: payload + actions | payload = reminder id; long body expands — *the buttons were removed by T07* | DONE |
| 3 | F25-T03 | Action use case | `HandleReminderNotificationAction` — *removed by T07* | REVERTED |
| 4 | F25-T04 | Tap → details | foreground + cold-start taps land on `/reminders/:id` once the router is up | DONE |
| 5 | F25-T05 | Background actions | background entry point, shared-isolate Drift, Android receiver, iOS registrant — *removed by T07* | REVERTED |
| 6 | F25-T06 | Quality gate + device pass | `dart format` / `flutter analyze` / `flutter test`; device checklist below | IN PROGRESS — gate re-run after T07 on 2026-10-04 (format clean, analyze: only the 16 infos already on `develop`, 2142 tests green); device checklist pending |
| 7 | F25-T07 | Remove the buttons (Option 3) | buttons, action use case and all background execution removed; database, manifest and `AppDelegate.swift` back to `develop`; tap-to-open kept | DONE |

## Exit DoD

Every alert's notification names its stage; hidden mode never shows the
title or note; tapping opens the right reminder, whether the app was killed,
in the background or open; the notification has no buttons.

## Device checklist (T06)

Android and iOS, details hidden and shown:

1. A reminder 3 days out, 1 day out, 2 hours out, and at its time — each
   notification's title matches the table.
2. Tap a notification with the app killed, backgrounded, and in the
   foreground — each lands on that reminder's details.
3. Tap a notification whose reminder was deleted in the app → the details
   screen's «not found» state, no crash.
4. A note longer than one line expands on Android.
5. No buttons appear on either platform.
