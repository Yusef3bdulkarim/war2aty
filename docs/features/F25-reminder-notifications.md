# F25 · Reminder notifications

- **Branch:** `feature/reminder-notifications`, based on `develop` · **Milestone:** post-F24
- **Depends on:** F09 (reminders, `ReminderScheduler`, the notification port), F11-T10 (the notification-privacy setting)
- **Progress:** 3 / 6 DONE

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
6. **Two action buttons: «تم» (complete) and «أجّل ساعة» (snooze one hour)**,
   handled without opening the app.
7. **English mirrors all of it** in `EnStrings`.

Derived, not in the owner's table: «النهارده» for an event with no time
whose alert is on the event day, and «دلوقتي» also covers an alert that fires
after the event (a snoozed overdue reminder). Times and digits use the app's
existing formatters (`formatWallClockTime`, Western digits) so a notification
reads the same as the reminder details screen.

## Tasks

| # | ID | Task | Output | Status |
|---|---|---|---|---|
| 1 | F25-T01 | Escalating copy | `reminderNotificationContent` per alert; ar/en strings; scheduler passes the alert | DONE |
| 2 | F25-T02 | Port: payload + actions | plugin-free `ReminderNotificationResponse`; payload = reminder id; «تم»/«أجّل ساعة» buttons (Android per notification, iOS category); long body expands | DONE |
| 3 | F25-T03 | Action use case | `HandleReminderNotificationAction`: complete / snooze 1h, ignores a reminder no longer pending, awaits reconcile | DONE |
| 4 | F25-T04 | Tap → details | foreground + cold-start taps land on `/reminders/:id` once the router is up | TODO |
| 5 | F25-T05 | Background actions | `@pragma('vm:entry-point')` handler + its own minimal composition; Drift shared across isolates; Android `ActionBroadcastReceiver`; iOS plugin registrant | TODO |
| 6 | F25-T06 | Quality gate + device pass | `dart format` / `flutter analyze` / `flutter test`; device checklist below | TODO |

## Exit DoD

Every alert's notification names its stage; hidden mode never shows the
title or note; tapping opens the right reminder; «تم» completes and «أجّل
ساعة» re-fires an hour later, from a locked phone, with the app killed, and
the open app reflects either within a moment.

## Device checklist (T06)

Android and iOS, details hidden and shown:

1. A reminder 3 days out, 1 day out, 2 hours out, and at its time — each
   notification's title matches the table.
2. Tap a notification with the app killed, backgrounded, and in the
   foreground — each lands on that reminder's details.
3. «تم» with the app killed → the reminder is in «المكتملة» on next launch,
   and its remaining alerts never fire.
4. «أجّل ساعة» with the app killed → a new notification an hour later.
5. «تم» while the reminders tab is open in the background → the list updates
   on return without a manual refresh.
