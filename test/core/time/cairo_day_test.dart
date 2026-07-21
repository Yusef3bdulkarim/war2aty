import 'package:flutter_test/flutter_test.dart';
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
}
