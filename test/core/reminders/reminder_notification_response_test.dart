import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/reminders/reminder_notification_response.dart';

void main() {
  group('reminderNotificationResponseOf', () {
    test('a tap on the notification itself opens the reminder', () {
      expect(
        reminderNotificationResponseOf(payload: 'r1', actionId: null),
        const ReminderNotificationOpened('r1'),
      );
    });

    test('an empty action id is a tap too', () {
      expect(
        reminderNotificationResponseOf(payload: 'r1', actionId: ''),
        const ReminderNotificationOpened('r1'),
      );
    });

    test('«تم» completes the reminder', () {
      expect(
        reminderNotificationResponseOf(payload: 'r1', actionId: 'complete'),
        const ReminderNotificationActionChosen(
          'r1',
          ReminderNotificationAction.complete,
        ),
      );
    });

    test('«أجّل ساعة» snoozes the reminder', () {
      expect(
        reminderNotificationResponseOf(payload: 'r1', actionId: 'snooze'),
        const ReminderNotificationActionChosen(
          'r1',
          ReminderNotificationAction.snooze,
        ),
      );
    });

    test('no payload (a notification from before F25): nothing to act on', () {
      expect(
        reminderNotificationResponseOf(payload: null, actionId: null),
        isNull,
      );
      expect(
        reminderNotificationResponseOf(payload: '', actionId: 'complete'),
        isNull,
      );
    });

    test('an unknown button: nothing to act on, never a guess', () {
      expect(
        reminderNotificationResponseOf(payload: 'r1', actionId: 'delete'),
        isNull,
      );
    });
  });

  test('labels come from the strings, one per action', () {
    const ar = ArStrings();
    final labels = ReminderNotificationActionLabels.of(ar);

    expect(labels.labelOf(ReminderNotificationAction.complete), 'تم');
    expect(labels.labelOf(ReminderNotificationAction.snooze), 'أجّل ساعة');
  });
}
