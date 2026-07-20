# F11 · Settings & Privacy

- **Branch:** `feature/settings` · **Milestone:** M8
- **Depends on:** F00, F08/F09 (delete-all), F10 (audio prefs) · **Feeds:** whole-app locale/theme/consent
- **Progress:** 0 / 12 DONE

Settings hub. Includes the **AR/EN language switch** (the approved bilingual addition to the design).

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F11-T01 | Settings scaffold + sections | «الإعدادات» layout | TODO |
| 2 | F11-T02 | Analysis consent | «السماح بإرسال النص للتحليل» toggle | TODO |
| 3 | F11-T03 | Processing-mode | «طريقة معالجة الأوراق» | TODO |
| 4 | F11-T04 | Language switch AR/EN | `LocaleController` + persist; flips whole app + direction | TODO |
| 5 | F11-T05 | Text size | عادي/كبير/كبير جدًا | TODO |
| 6 | F11-T06 | High contrast | «تباين عالي» | TODO |
| 7 | F11-T07 | Audio settings | rate/voice/resume | TODO |
| 8 | F11-T08 | Camera permission status | state + «فتح إعدادات الكاميرا» | TODO |
| 9 | F11-T09 | Notification permission status | state + open settings | TODO |
| 10 | F11-T10 | Notification-privacy toggle | «إخفاء التفاصيل الحساسة» | TODO |
| 11 | F11-T11 | Delete-all | documents / reminders / all app data + confirmations | TODO |
| 12 | F11-T12 | About | supported docs / usage limits / privacy policy / version | TODO |

## Exit DoD
Settings persist; language toggle flips whole app AR↔EN + direction; delete-all cascades to F08/F09; consent respected before analysis.
