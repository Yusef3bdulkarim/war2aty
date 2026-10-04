import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_notification_content.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/time/cairo_day.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();
  const note = 'السداد عن طريق فوري';

  /// 15 October 2026 — Egyptian summer time (UTC+3), so a wrong fixed +2
  /// offset anywhere would show up as a shifted day or hour.
  Reminder reminder({int? minuteOfDay = 600, String? description = note}) =>
      Reminder(
        id: 'r1',
        title: 'فاتورة الكهرباء',
        description: description,
        eventDate: DateTime(2026, 10, 15),
        eventMinuteOfDay: minuteOfDay,
        status: ReminderStatus.pending,
        isManual: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  /// A Cairo wall-clock instant, as the scheduler would be handed it.
  DateTime cairo(int day, int hour, [int minute = 0]) =>
      cairoInstant(2026, 10, day, hour, minute);

  ReminderNotificationContent content(
    DateTime firesAt, {
    Reminder? of,
    bool hidden = false,
    bool english = false,
  }) => reminderNotificationContent(
    of ?? reminder(),
    english ? en : ar,
    firesAt: firesAt,
    hideSensitiveDetails: hidden,
  );

  group('title: how close it is, then the reminder title — both modes', () {
    for (final hidden in [false, true]) {
      final mode = hidden ? 'hidden' : 'shown';

      test('$mode: three days before', () {
        expect(
          content(cairo(12, 10), hidden: hidden).title,
          'فاضل 3 أيام: فاتورة الكهرباء',
        );
      });

      test('$mode: the day before', () {
        expect(
          content(cairo(14, 10), hidden: hidden).title,
          'بكرة آخر ميعاد: فاتورة الكهرباء',
        );
      });

      test('$mode: two hours before', () {
        expect(
          content(cairo(15, 8), hidden: hidden).title,
          'بعد ساعتين: فاتورة الكهرباء',
        );
      });

      test('$mode: at the event time', () {
        expect(
          content(cairo(15, 10), hidden: hidden).title,
          'دلوقتي: فاتورة الكهرباء',
        );
      });
    }

    test('two days reads «يومين», not «2 أيام»', () {
      expect(content(cairo(13, 10)).title, 'فاضل يومين: فاتورة الكهرباء');
    });

    test('eleven days or more reads «يوم» in the singular', () {
      expect(content(cairo(4, 10)).title, 'فاضل 11 يوم: فاتورة الكهرباء');
    });

    test('the day before by the calendar, even under 24 hours', () {
      expect(
        content(cairo(14, 23, 30)).title,
        'بكرة آخر ميعاد: فاتورة الكهرباء',
      );
    });

    test('three to ten hours reads «ساعات»', () {
      expect(content(cairo(15, 5)).title, 'بعد 5 ساعات: فاتورة الكهرباء');
    });

    test('under an hour: minutes away', () {
      expect(content(cairo(15, 9, 40)).title, 'بعد 20 دقيقة: فاتورة الكهرباء');
    });

    test('after the event (a snoozed missed reminder) still reads now', () {
      expect(content(cairo(16, 9)).title, 'دلوقتي: فاتورة الكهرباء');
      expect(content(cairo(15, 11)).title, 'دلوقتي: فاتورة الكهرباء');
    });

    test('just past midnight Cairo summer time is the event day, not the '
        'day before', () {
      // 00:30 on the 15th Cairo is 21:30 UTC on the 14th; a fixed +2 offset
      // would read it as 23:30 on the 14th and say «بكرة».
      expect(content(cairo(15, 0, 30)).title, 'بعد 10 ساعات: فاتورة الكهرباء');
    });

    test('an event with no time, on its day: today', () {
      expect(
        content(cairo(15, 9), of: reminder(minuteOfDay: null)).title,
        'النهارده: فاتورة الكهرباء',
      );
    });
  });

  group('body, details shown', () {
    test('time and note, separated by a bullet', () {
      expect(content(cairo(12, 10)).body, '10:00 صباحًا • $note');
    });

    test('the same at every stage — the title already says how close', () {
      for (final firesAt in [cairo(14, 10), cairo(15, 8), cairo(15, 10)]) {
        expect(content(firesAt).body, '10:00 صباحًا • $note');
      }
    });

    test('no note: the time alone, as «الساعة …»', () {
      expect(
        content(cairo(14, 10), of: reminder(description: null)).body,
        'الساعة 10:00 صباحًا',
      );
    });

    test('a blank note counts as none', () {
      expect(
        content(cairo(14, 10), of: reminder(description: '   ')).body,
        'الساعة 10:00 صباحًا',
      );
    });

    test('no event time: the note alone, never an invented time', () {
      expect(
        content(cairo(12, 10), of: reminder(minuteOfDay: null)).body,
        note,
      );
    });

    test('no event time and no note: «اضغط للمتابعة»', () {
      expect(
        content(
          cairo(12, 10),
          of: reminder(minuteOfDay: null, description: null),
        ).body,
        'اضغط للمتابعة',
      );
    });
  });

  group('body, details hidden — the time only, never the note', () {
    test('shows the bare time', () {
      expect(content(cairo(12, 10), hidden: true).body, '10:00 صباحًا');
      expect(content(cairo(15, 10), hidden: true).body, '10:00 صباحًا');
    });

    test('never the note, at any stage', () {
      for (final firesAt in [
        cairo(12, 10),
        cairo(14, 10),
        cairo(15, 8),
        cairo(15, 9, 40),
        cairo(15, 10),
      ]) {
        final shown = content(firesAt, hidden: true);
        expect('${shown.title} ${shown.body}', isNot(contains('فوري')));
      }
    });

    test('no event time: «اضغط للمتابعة»', () {
      expect(
        content(
          cairo(12, 10),
          of: reminder(minuteOfDay: null),
          hidden: true,
        ).body,
        'اضغط للمتابعة',
      );
    });
  });

  group('English mirrors the structure', () {
    const englishNote = 'Payment via Fawry';
    Reminder englishReminder({String? description = englishNote}) => Reminder(
      id: 'r1',
      title: 'Electricity Bill',
      description: description,
      eventDate: DateTime(2026, 10, 15),
      eventMinuteOfDay: 600,
      status: ReminderStatus.pending,
      isManual: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('titles', () {
      final of = englishReminder();
      expect(
        content(cairo(12, 10), of: of, english: true).title,
        'In 3 days: Electricity Bill',
      );
      expect(
        content(cairo(14, 10), of: of, english: true).title,
        'Due tomorrow: Electricity Bill',
      );
      expect(
        content(cairo(15, 8), of: of, english: true).title,
        'In 2 hours: Electricity Bill',
      );
      expect(
        content(cairo(15, 10), of: of, english: true).title,
        'Now: Electricity Bill',
      );
    });

    test('bodies', () {
      expect(
        content(cairo(12, 10), of: englishReminder(), english: true).body,
        '10:00 AM • Payment via Fawry',
      );
      expect(
        content(
          cairo(12, 10),
          of: englishReminder(description: null),
          english: true,
        ).body,
        'At 10:00 AM',
      );
      expect(
        content(
          cairo(12, 10),
          of: englishReminder(),
          english: true,
          hidden: true,
        ).body,
        '10:00 AM',
      );
    });
  });
}
