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
      // 08:00 UTC == 10:00 Cairo.
      final label = alertTimeLabel(
        ar,
        DateTime.utc(2026, 8, 24, 8),
        offset: null,
      );

      expect(label, contains('24'));
      expect(label, contains('أغسطس'));
      expect(label, contains('10:00'));
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
