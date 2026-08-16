import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/alert_time_label.dart';
import 'package:war2aty/core/reminders/alert_time_offset.dart';

void main() {
  const ar = ArStrings();

  group('alertTimeLabel', () {
    test('a preset alert shows its offset label, not the raw time', () {
      final label = alertTimeLabel(
        ar,
        DateTime.utc(2026, 8, 24, 8),
        offset: AlertTimeOffset.oneDayBefore,
      );

      expect(label, ar.reminderAlertOffsetOneDay);
    });

    test('a custom alert shows the Cairo date and time written out', () {
      // January: outside Egypt's DST window, so 08:00 UTC == 10:00 Cairo.
      final label = alertTimeLabel(
        ar,
        DateTime.utc(2026, 1, 24, 8),
        offset: null,
      );

      expect(label, contains('24'));
      expect(label, contains('يناير'));
      expect(label, contains('10:00'));
    });

    test('a custom alert during DST shows the real Cairo time', () {
      // August: within Egypt's DST window, so 08:00 UTC == 11:00 Cairo, not
      // 10:00 — the same real zone the alert was scheduled through.
      final label = alertTimeLabel(
        ar,
        DateTime.utc(2026, 8, 24, 8),
        offset: null,
      );

      expect(label, contains('11:00'));
    });
  });

  group('alertOffsetLabel', () {
    test('every offset has a distinct label', () {
      final labels = AlertTimeOffset.values
          .map((o) => alertOffsetLabel(ar, o))
          .toSet();

      expect(labels, hasLength(AlertTimeOffset.values.length));
    });
  });
}
