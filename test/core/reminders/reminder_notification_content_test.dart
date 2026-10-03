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
  const note = 'ادفع في البوستة أو فوري';

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

  ReminderNotificationContent shown(
    DateTime firesAt, {
    Reminder? of,
    bool english = false,
  }) => reminderNotificationContent(
    of ?? reminder(),
    english ? en : ar,
    firesAt: firesAt,
    hideSensitiveDetails: false,
  );

  ReminderNotificationContent hidden(DateTime firesAt, {Reminder? of}) =>
      reminderNotificationContent(
        of ?? reminder(),
        ar,
        firesAt: firesAt,
        hideSensitiveDetails: true,
      );

  group('details shown — the tone rises as the event gets closer', () {
    test('three days before: days left, the full date, then the note', () {
      final content = shown(cairo(12, 10));

      expect(content.title, 'فاضل 3 أيام: فاتورة الكهرباء');
      expect(
        content.body,
        'الموعد 15 أكتوبر الساعة 10:00 صباحًا. ادفع في البوستة أو فوري',
      );
    });

    test('two days before reads «يومين», not «2 أيام»', () {
      expect(shown(cairo(13, 10)).title, 'فاضل يومين: فاتورة الكهرباء');
    });

    test('eleven days or more reads «يوم» in the singular', () {
      expect(shown(cairo(4, 10)).title, 'فاضل 11 يوم: فاتورة الكهرباء');
    });

    test('the day before: tomorrow, the time, then the note', () {
      final content = shown(cairo(14, 10));

      expect(content.title, 'بكرة آخر ميعاد: فاتورة الكهرباء');
      expect(content.body, 'الساعة 10:00 صباحًا. ادفع في البوستة أو فوري');
    });

    test('the day before by the calendar, even under 24 hours', () {
      expect(shown(cairo(14, 23, 30)).title, 'بكرة آخر ميعاد: فاتورة الكهرباء');
    });

    test('two hours before: hours away', () {
      final content = shown(cairo(15, 8));

      expect(content.title, 'بعد ساعتين: فاتورة الكهرباء');
      expect(content.body, 'الساعة 10:00 صباحًا. ادفع في البوستة أو فوري');
    });

    test('three to ten hours reads «ساعات»', () {
      expect(shown(cairo(15, 5)).title, 'بعد 5 ساعات: فاتورة الكهرباء');
    });

    test('under an hour: minutes away', () {
      expect(shown(cairo(15, 9, 40)).title, 'بعد 20 دقيقة: فاتورة الكهرباء');
    });

    test('at the event time: now', () {
      final content = shown(cairo(15, 10));

      expect(content.title, 'دلوقتي: فاتورة الكهرباء');
      expect(content.body, 'ميعادها جه. ادفع في البوستة أو فوري');
    });

    test('after the event (a snoozed missed reminder) still reads now', () {
      expect(shown(cairo(16, 9)).title, 'دلوقتي: فاتورة الكهرباء');
      expect(shown(cairo(15, 11)).title, 'دلوقتي: فاتورة الكهرباء');
    });

    test('just past midnight Cairo summer time is the event day, not the '
        'day before', () {
      // 00:30 on the 15th Cairo is 21:30 UTC on the 14th; a fixed +2 offset
      // would read it as 23:30 on the 14th and say «بكرة».
      expect(shown(cairo(15, 0, 30)).title, 'بعد 10 ساعات: فاتورة الكهرباء');
    });
  });

  group('details shown — an event with no time', () {
    Reminder untimed({String? description = note}) =>
        reminder(minuteOfDay: null, description: description);

    test('days before: the date alone, never an invented time', () {
      final content = shown(cairo(12, 10), of: untimed());

      expect(content.body, 'الموعد 15 أكتوبر. ادفع في البوستة أو فوري');
    });

    test('the day before: only the note', () {
      final content = shown(cairo(14, 10), of: untimed());

      expect(content.title, 'بكرة آخر ميعاد: فاتورة الكهرباء');
      expect(content.body, note);
    });

    test('on the day: today', () {
      final content = shown(cairo(15, 9), of: untimed());

      expect(content.title, 'النهارده: فاتورة الكهرباء');
      expect(content.body, note);
    });

    test('on the day with no note: no body at all', () {
      final content = shown(cairo(15, 9), of: untimed(description: null));

      expect(content.body, isNull);
    });
  });

  group('the note', () {
    test('a blank note adds nothing', () {
      final content = shown(cairo(14, 10), of: reminder(description: '   '));

      expect(content.body, 'الساعة 10:00 صباحًا.');
    });

    test('no note: only when', () {
      final content = shown(cairo(15, 10), of: reminder(description: null));

      expect(content.body, 'ميعادها جه.');
    });
  });

  group('details hidden (F09-T14) — when, never what', () {
    test('says how far away, behind generic wording', () {
      expect(hidden(cairo(12, 10)).title, 'عندك موعد بعد 3 أيام');
      expect(hidden(cairo(14, 10)).title, 'عندك موعد بكرة');
      expect(hidden(cairo(15, 8)).title, 'عندك موعد بعد ساعتين');
      expect(hidden(cairo(15, 9, 40)).title, 'عندك موعد بعد 20 دقيقة');
      expect(hidden(cairo(15, 10)).title, 'عندك موعد دلوقتي');
      expect(
        hidden(cairo(15, 9), of: reminder(minuteOfDay: null)).title,
        'عندك موعد النهارده',
      );
    });

    test('never shows the title or the note, at any stage', () {
      for (final firesAt in [
        cairo(12, 10),
        cairo(14, 10),
        cairo(15, 8),
        cairo(15, 9, 40),
        cairo(15, 10),
      ]) {
        final content = hidden(firesAt);
        final text = '${content.title} ${content.body}';

        expect(text, isNot(contains('فاتورة')));
        expect(text, isNot(contains('البوستة')));
        expect(text, isNot(contains('10:00')));
        expect(content.body, ar.reminderNotificationHiddenBody);
      }
    });
  });

  group('English', () {
    test('mirrors every stage', () {
      expect(
        shown(cairo(12, 10), english: true).title,
        '3 days left: فاتورة الكهرباء',
      );
      expect(
        shown(cairo(14, 10), english: true).title,
        'Due tomorrow: فاتورة الكهرباء',
      );
      expect(
        shown(cairo(15, 8), english: true).title,
        'In 2 hours: فاتورة الكهرباء',
      );
      expect(shown(cairo(15, 10), english: true).title, 'Now: فاتورة الكهرباء');
      expect(
        shown(cairo(12, 10), english: true).body,
        'It\'s on 15 October at 10:00 AM. $note',
      );
    });
  });
}
