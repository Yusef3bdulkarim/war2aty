import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/notifications/reminder_notification_taps.dart';

void main() {
  group('ReminderNotificationTaps', () {
    test('hands over the tapped reminder exactly once', () {
      final taps = ReminderNotificationTaps()..open('r1');

      expect(taps.take(), 'r1');
      expect(taps.take(), isNull);
    });

    test('a newer tap replaces one not yet shown', () {
      final taps = ReminderNotificationTaps()
        ..open('r1')
        ..open('r2');

      expect(taps.take(), 'r2');
    });

    test('tells its listener a tap arrived', () {
      var heard = 0;
      ReminderNotificationTaps()
        ..addListener(() => heard++)
        ..open('r1');

      expect(heard, 1);
    });
  });
}
