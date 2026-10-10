import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/quick_reminder_date.dart';
import 'package:war2aty/core/time/cairo_day.dart';

void main() {
  /// The slot for [kind] at a given moment. Every test reads one this way so
  /// a reordering of the list cannot silently move what a test is asserting.
  QuickReminderSlot slotAt(QuickReminderDate kind, DateTime now) =>
      quickReminderSlots(now: now).firstWhere((slot) => slot.kind == kind);

  /// `(year, month, day)` of a slot's calendar day — the three fields
  /// anything downstream actually reads.
  (int, int, int) ymd(QuickReminderSlot slot) =>
      (slot.eventDate.year, slot.eventDate.month, slot.eventDate.day);

  group('the list itself', () {
    test('offers exactly the three kinds, in reading order', () {
      final slots = quickReminderSlots(now: cairoInstant(2026, 10, 12, 14));

      expect(slots.map((s) => s.kind), [
        QuickReminderDate.tomorrow,
        QuickReminderDate.nextWeek,
        QuickReminderDate.endOfMonth,
      ]);
    });

    test('every slot carries 09:00 as its minute of day', () {
      final slots = quickReminderSlots(now: cairoInstant(2026, 10, 12, 14));

      for (final slot in slots) {
        expect(slot.eventMinuteOfDay, kQuickReminderMinuteOfDay);
        expect(slot.eventMinuteOfDay, 540);
      }
    });

    test(
      'a slot reads back as 09:00 on the Cairo clock, winter and summer',
      () {
        // The point of carrying a day plus a minute rather than an instant:
        // 09:00 must stay 09:00 across the DST change, not become 08:00 or
        // 10:00. July is +03, January is +02.
        for (final now in [
          cairoInstant(2026, 7, 14, 12),
          cairoInstant(2026, 1, 14, 12),
        ]) {
          final tomorrow = slotAt(QuickReminderDate.tomorrow, now);
          final wall = cairoWallClockOf(tomorrow.eventInstant);

          expect(wall.hour, 9, reason: 'at $now');
          expect(wall.minute, 0, reason: 'at $now');
        }
      },
    );
  });

  group('tomorrow and next week', () {
    test('are one day and seven days on', () {
      final now = cairoInstant(2026, 10, 12, 14);

      expect(ymd(slotAt(QuickReminderDate.tomorrow, now)), (2026, 10, 13));
      expect(ymd(slotAt(QuickReminderDate.nextWeek, now)), (2026, 10, 19));
    });

    test('roll over the end of a 31-day month', () {
      final now = cairoInstant(2026, 10, 31, 14);

      expect(ymd(slotAt(QuickReminderDate.tomorrow, now)), (2026, 11, 1));
      expect(ymd(slotAt(QuickReminderDate.nextWeek, now)), (2026, 11, 7));
    });

    test('roll over the end of a 30-day month', () {
      final now = cairoInstant(2026, 11, 30, 14);

      expect(ymd(slotAt(QuickReminderDate.tomorrow, now)), (2026, 12, 1));
      expect(ymd(slotAt(QuickReminderDate.nextWeek, now)), (2026, 12, 7));
    });

    test('roll over the end of the year', () {
      final now = cairoInstant(2026, 12, 31, 14);

      expect(ymd(slotAt(QuickReminderDate.tomorrow, now)), (2027, 1, 1));
      expect(ymd(slotAt(QuickReminderDate.nextWeek, now)), (2027, 1, 7));
    });

    test('handle a short February and a leap one', () {
      // 2027 is not a leap year; 2028 is.
      final common = cairoInstant(2027, 2, 28, 14);
      expect(ymd(slotAt(QuickReminderDate.tomorrow, common)), (2027, 3, 1));

      final leap = cairoInstant(2028, 2, 28, 14);
      expect(ymd(slotAt(QuickReminderDate.tomorrow, leap)), (2028, 2, 29));
    });
  });

  group('the end of the month', () {
    test('is the last day of a 31-day month', () {
      expect(
        ymd(slotAt(QuickReminderDate.endOfMonth, cairoInstant(2026, 10, 5))),
        (2026, 10, 31),
      );
    });

    test('is the last day of a 30-day month', () {
      expect(
        ymd(slotAt(QuickReminderDate.endOfMonth, cairoInstant(2026, 11, 5))),
        (2026, 11, 30),
      );
    });

    test('is 28 February in a common year and 29 in a leap year', () {
      expect(
        ymd(slotAt(QuickReminderDate.endOfMonth, cairoInstant(2027, 2, 5))),
        (2027, 2, 28),
      );
      expect(
        ymd(slotAt(QuickReminderDate.endOfMonth, cairoInstant(2028, 2, 5))),
        (2028, 2, 29),
      );
    });

    test('still points at today while 09:00 has not arrived', () {
      // The 31st at 06:00 — the end of the month is three hours away and
      // perfectly usable.
      expect(
        ymd(
          slotAt(QuickReminderDate.endOfMonth, cairoInstant(2026, 10, 31, 6)),
        ),
        (2026, 10, 31),
      );
    });

    test('rolls into next month once 09:00 has gone by', () {
      // The 31st at noon. Offering "the end of the month" would hand the
      // user a reminder three hours in the past, missed the moment it saved.
      expect(
        ymd(
          slotAt(QuickReminderDate.endOfMonth, cairoInstant(2026, 10, 31, 12)),
        ),
        (2026, 11, 30),
      );
    });

    test('rolls across the year boundary too', () {
      expect(
        ymd(
          slotAt(QuickReminderDate.endOfMonth, cairoInstant(2026, 12, 31, 12)),
        ),
        (2027, 1, 31),
      );
    });

    test('rolls from a 31st into February, keeping February short', () {
      // The roll-forward must not carry the day number with it: January 31st
      // plus a month is not «February 31st».
      expect(
        ymd(
          slotAt(QuickReminderDate.endOfMonth, cairoInstant(2027, 1, 31, 12)),
        ),
        (2027, 2, 28),
      );
    });

    test('09:00 exactly is already gone', () {
      // Not `isAfter` by a hair: at 09:00:00 the event is now, and the
      // alert the form seeds at the event's own time would fire into the
      // past.
      expect(
        ymd(
          slotAt(QuickReminderDate.endOfMonth, cairoInstant(2026, 10, 31, 9)),
        ),
        (2026, 11, 30),
      );
    });
  });

  group('the day is Cairo\'s, not the device\'s or a fixed offset\'s', () {
    test('after Cairo midnight, tomorrow is the day after the new one', () {
      // 21:30 UTC in July is 00:30 Cairo on the 15th — Egypt is on +03 then.
      // So "tomorrow" is the 16th.
      final now = DateTime.utc(2026, 7, 14, 21, 30);

      expect(cairoWallClockOf(now).day, 15, reason: 'the premise');
      expect(ymd(slotAt(QuickReminderDate.tomorrow, now)), (2026, 7, 16));
    });

    test('the fixed +2 offset would have got that hour wrong', () {
      // `cairoDateOf` adds a flat two hours, which is Egypt's winter offset.
      // In the first summer hour after midnight it therefore names the
      // previous day — which is exactly why `quickReminderSlots` reads the
      // real zone instead. Pinned so nobody "simplifies" it back.
      final now = DateTime.utc(2026, 7, 14, 21, 30);

      expect(cairoDateOf(now), DateTime.utc(2026, 7, 14));
      expect(cairoWallClockOf(now).day, 15);
    });

    test('just before Cairo midnight, tomorrow is still the next day', () {
      // 20:59 UTC in July is 23:59 Cairo on the 14th.
      final now = DateTime.utc(2026, 7, 14, 20, 59);

      expect(cairoWallClockOf(now).day, 14, reason: 'the premise');
      expect(ymd(slotAt(QuickReminderDate.tomorrow, now)), (2026, 7, 15));
    });

    test('does not depend on the zone the instant is expressed in', () {
      final utc = DateTime.utc(2026, 10, 12, 14);

      expect(
        quickReminderSlots(now: utc.toLocal()),
        quickReminderSlots(now: utc),
      );
    });
  });

  group('every slot is in the future', () {
    test('at every hour of a month end, in both DST states', () {
      // The invariant the whole helper exists to keep: the form seeds its
      // first alert at the event's own time, so a slot in the past would
      // show the user's very first reminder as «فائت» the instant they
      // saved it.
      final starts = [
        cairoInstant(2026, 10, 25), // the DST change itself falls in this week
        cairoInstant(2026, 1, 28),
        cairoInstant(2027, 2, 26),
        cairoInstant(2028, 2, 27), // leap
        cairoInstant(2026, 12, 29),
      ];

      for (final start in starts) {
        for (var hour = 0; hour < 24 * 7; hour++) {
          final now = start.add(Duration(hours: hour));
          for (final slot in quickReminderSlots(now: now)) {
            expect(
              slot.eventInstant.isAfter(now),
              isTrue,
              reason:
                  '${slot.kind.name} at $now resolved to '
                  '${slot.eventInstant}',
            );
          }
        }
      }
    });
  });

  group('QuickReminderSlot value semantics', () {
    test('two slots for the same day and minute are equal', () {
      final a = QuickReminderSlot(
        kind: QuickReminderDate.tomorrow,
        eventDate: DateTime(2026, 10, 13),
        eventMinuteOfDay: 540,
      );
      final b = QuickReminderSlot(
        kind: QuickReminderDate.tomorrow,
        eventDate: DateTime(2026, 10, 13),
        eventMinuteOfDay: 540,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different kind on the same day is a different slot', () {
      // Two kinds can legitimately land on the same date — "tomorrow" on the
      // 30th of a 31-day month is not "the end of the month", and the row
      // the user tapped still matters.
      final tomorrow = QuickReminderSlot(
        kind: QuickReminderDate.tomorrow,
        eventDate: DateTime(2026, 10, 31),
        eventMinuteOfDay: 540,
      );
      final endOfMonth = QuickReminderSlot(
        kind: QuickReminderDate.endOfMonth,
        eventDate: DateTime(2026, 10, 31),
        eventMinuteOfDay: 540,
      );

      expect(tomorrow, isNot(endOfMonth));
    });

    test('toString names the kind and the day', () {
      final slot = QuickReminderSlot(
        kind: QuickReminderDate.endOfMonth,
        eventDate: DateTime(2026, 10, 31),
        eventMinuteOfDay: 540,
      );

      expect(slot.toString(), contains('endOfMonth'));
      expect(slot.toString(), contains('2026-10-31'));
    });
  });
}
