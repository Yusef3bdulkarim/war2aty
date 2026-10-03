import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/notifications/reminder_notification_taps.dart';
import 'package:war2aty/core/reminders/reminder_notification_response.dart';
import 'package:war2aty/core/reminders/usecases/handle_reminder_notification_action.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

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

  group('dispatchReminderNotificationResponse', () {
    late FakeRemindersRepository repository;
    late ReminderNotificationTaps taps;
    late HandleReminderNotificationAction handleAction;

    setUp(() {
      repository = FakeRemindersRepository()
        ..pendingOutcome = Ok([fakeReminder()]);
      taps = ReminderNotificationTaps();
      handleAction = HandleReminderNotificationAction(
        repository,
        FakeReminderScheduler(),
      );
    });
    tearDown(() => repository.dispose());

    test('a tap opens the reminder', () {
      dispatchReminderNotificationResponse(
        const ReminderNotificationOpened('r1'),
        taps: taps,
        handleAction: handleAction,
      );

      expect(taps.take(), 'r1');
    });

    test('a button press acts on the reminder without opening it', () async {
      dispatchReminderNotificationResponse(
        const ReminderNotificationActionChosen(
          'r1',
          ReminderNotificationAction.complete,
        ),
        taps: taps,
        handleAction: handleAction,
      );
      await pumpEventQueue();

      expect(repository.lastCompletedId, 'r1');
      expect(taps.take(), isNull);
    });
  });
}
