import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/reminders/reminder_due_label.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  // Cairo is UTC+2, so 08:00 UTC is 10:00 in Cairo.
  final now = DateTime.utc(2026, 7, 22, 8);

  group('formatClockTime', () {
    test('reads a morning time on a 12-hour clock', () {
      expect(formatClockTime(ar, DateTime.utc(2026, 7, 22, 8)), '10:00 صباحًا');
      expect(formatClockTime(en, DateTime.utc(2026, 7, 22, 8)), '10:00 AM');
    });

    test('reads an afternoon time', () {
      // 15:30 UTC → 17:30 Cairo → 5:30 PM.
      expect(formatClockTime(en, DateTime.utc(2026, 7, 22, 15, 30)), '5:30 PM');
      expect(
        formatClockTime(ar, DateTime.utc(2026, 7, 22, 15, 30)),
        '5:30 مساءً',
      );
    });

    test('midnight and noon both read as 12, not 0', () {
      // 22:00 UTC → 00:00 Cairo next day.
      expect(formatClockTime(en, DateTime.utc(2026, 7, 21, 22)), '12:00 AM');
      // 10:00 UTC → 12:00 Cairo.
      expect(formatClockTime(en, DateTime.utc(2026, 7, 22, 10)), '12:00 PM');
    });

    test('pads the minutes', () {
      expect(formatClockTime(en, DateTime.utc(2026, 7, 22, 8, 5)), '10:05 AM');
    });
  });

  group('reminderDueLabel', () {
    test('says "today" for later the same Cairo day', () {
      final due = DateTime.utc(2026, 7, 22, 16);

      expect(
        reminderDueLabel(ar, due, now: now),
        'النهارده، الساعة 6:00 مساءً',
      );
      expect(reminderDueLabel(en, due, now: now), 'Today at 6:00 PM');
    });

    test('says "tomorrow" for the next Cairo day', () {
      final due = DateTime.utc(2026, 7, 23, 8);

      expect(reminderDueLabel(ar, due, now: now), 'بكرة، الساعة 10:00 صباحًا');
      expect(reminderDueLabel(en, due, now: now), 'Tomorrow at 10:00 AM');
    });

    test('falls back to a dated line further out', () {
      final due = DateTime.utc(2026, 8, 25, 8);

      expect(
        reminderDueLabel(ar, due, now: now),
        'يوم 25/8، الساعة 10:00 صباحًا',
      );
      expect(reminderDueLabel(en, due, now: now), 'On 25/8 at 10:00 AM');
    });

    test('groups by the Cairo day, not the UTC day', () {
      // 23:00 UTC on the 22nd is already 01:00 Cairo on the 23rd — which is
      // "tomorrow" to a user in Cairo, even though UTC still says today.
      final due = DateTime.utc(2026, 7, 22, 23);

      expect(reminderDueLabel(en, due, now: now), startsWith('Tomorrow'));
      expect(reminderDueLabel(en, due, now: now), contains('1:00 AM'));
    });

    test('a reminder just after Cairo midnight tonight reads as tomorrow', () {
      // 22:30 UTC = 00:30 Cairo on the 23rd.
      final due = DateTime.utc(2026, 7, 22, 22, 30);

      expect(reminderDueLabel(en, due, now: now), 'Tomorrow at 12:30 AM');
    });
  });
}
