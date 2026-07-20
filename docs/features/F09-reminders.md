# F09 · Reminders

- **Branch:** `feature/reminders` · **Milestone:** M7
- **Depends on:** F00 (db), F07/F08 (source), notifications core · **Feeds:** Home (upcoming), OS notifications
- **Progress:** 0 / 14 DONE

Local reminders (Drift = source of truth, not the scheduled notification). **Decision at start:** exact-alarm behavior + permission timing (Android 13+).

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F09-T01 | Reminder Drift schema + domain | `reminders` + `reminder_alerts` + migration | TODO |
| 2 | F09-T02 | Shared reminder form | reusable form widget | TODO |
| 3 | F09-T03 | Create-from-document-date | prefilled from result date | TODO |
| 4 | F09-T04 | Create-manual | «إضافة تذكير» | TODO |
| 5 | F09-T05 | Event-vs-alert time | event date/time ≠ alert datetime | TODO |
| 6 | F09-T06 | Missing-time handling | «الورقة مافيهاش وقت» → user picks alert time | TODO |
| 7 | F09-T07 | Multiple-dates selection | choose intended date | TODO |
| 8 | F09-T08 | Alerts (up to 3) | add/remove up to 3 alert times | TODO |
| 9 | F09-T09 | Notification permission | request on first reminder | TODO |
| 10 | F09-T10 | `ReminderScheduler` | schedule/reschedule/cancel; Africa/Cairo tz | TODO |
| 11 | F09-T11 | Lists | القادمة/الفائتة/المكتملة | TODO |
| 12 | F09-T12 | Snooze/complete/delete | actions + confirmations | TODO |
| 13 | F09-T13 | Reconcile-on-restart | DB ↔ OS scheduled state | TODO |
| 14 | F09-T14 | Notification privacy | hide sensitive details on lock screen (default on) | TODO |

## Exit DoD
Reminder fires at chosen alert; survives restart (reconcile); event time never fabricated; sensitive details hidden on lock screen.
