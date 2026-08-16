import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:war2aty/core/time/cairo_day.dart';

void main() {
  group('cairoDateOf', () {
    test('maps a mid-day UTC instant to the same Cairo date', () {
      expect(
        cairoDateOf(DateTime.utc(2026, 7, 21, 10)),
        DateTime.utc(2026, 7, 21),
      );
    });

    test('late-evening UTC already belongs to the next Cairo day', () {
      // 22:30 UTC == 00:30 Cairo the following day.
      expect(
        cairoDateOf(DateTime.utc(2026, 7, 21, 22, 30)),
        DateTime.utc(2026, 7, 22),
      );
    });

    test('exactly Cairo midnight rolls over to the next day', () {
      // 22:00 UTC == 00:00 Cairo the following day — the boundary itself.
      expect(
        cairoDateOf(DateTime.utc(2026, 7, 21, 22)),
        DateTime.utc(2026, 7, 22),
      );
    });

    test('just before Cairo midnight still counts as the current day', () {
      // 21:59 UTC == 23:59 Cairo, same day.
      expect(
        cairoDateOf(DateTime.utc(2026, 7, 21, 21, 59)),
        DateTime.utc(2026, 7, 21),
      );
    });

    test('is independent of the input timezone', () {
      final utc = DateTime.utc(2026, 7, 21, 10);
      final elsewhere = utc.toLocal();

      expect(cairoDateOf(elsewhere), cairoDateOf(utc));
    });

    test('returns a date with no time component', () {
      final date = cairoDateOf(DateTime.utc(2026, 7, 21, 13, 45, 30));

      expect(date.hour, 0);
      expect(date.minute, 0);
      expect(date.second, 0);
    });
  });

  group('nextCairoResetAfter', () {
    test('resets at the end of the current Cairo day', () {
      // 2026-07-22 00:00 Cairo == 2026-07-21 22:00 UTC.
      expect(
        nextCairoResetAfter(DateTime.utc(2026, 7, 21, 10)),
        DateTime.utc(2026, 7, 21, 22),
      );
    });

    test('is always in the future', () {
      final now = DateTime.utc(2026, 7, 21, 21, 59);

      expect(nextCairoResetAfter(now).isAfter(now), isTrue);
    });
  });

  group('cairoInstant', () {
    // Outside Egypt's DST window (last Friday of April to last Thursday of
    // September) — [cairoLocalOf]'s fixed +2h and the real IANA data agree
    // here, so the round trip and the plain offset checks below hold. See
    // the dedicated 'observes DST' group for the window where they diverge,
    // which is the whole reason this function no longer uses the fixed
    // offset.
    test('reverses cairoLocalOf, outside DST', () {
      final instant = DateTime.utc(2026, 1, 24, 8); // 10:00 Cairo.
      final cairo = cairoLocalOf(instant);

      expect(
        cairoInstant(
          cairo.year,
          cairo.month,
          cairo.day,
          cairo.hour,
          cairo.minute,
        ),
        instant,
      );
    });

    test('10 AM Cairo in January is 08:00 UTC', () {
      expect(cairoInstant(2026, 1, 24, 10), DateTime.utc(2026, 1, 24, 8));
    });

    test('defaults the time of day to midnight', () {
      expect(cairoInstant(2026, 1, 24), DateTime.utc(2026, 1, 23, 22));
    });

    group('observes DST', () {
      // Egypt reinstated DST in 2023: UTC+3 from the last Friday of April to
      // the last Thursday of September. This is the exact bug this function
      // fixes — the old fixed `kCairoUtcOffset` (+2h) was wrong for exactly
      // this window, which is why reminders drifted by an hour in summer.
      test('10 AM Cairo in August is 07:00 UTC, not 08:00', () {
        expect(cairoInstant(2026, 8, 24, 10), DateTime.utc(2026, 8, 24, 7));
      });

      test(
        'agrees with the real Africa/Cairo zone used to schedule alerts',
        () {
          final expected = tz.TZDateTime(
            tz.getLocation('Africa/Cairo'),
            2026,
            8,
            24,
            10,
          ).toUtc();

          expect(cairoInstant(2026, 8, 24, 10), expected);
        },
      );
    });
  });
}
