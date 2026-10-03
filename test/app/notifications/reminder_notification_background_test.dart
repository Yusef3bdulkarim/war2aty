import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/notifications/reminder_notification_background.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/reminders/drift_reminders_repository.dart';
import 'package:war2aty/core/reminders/notification_id.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_notification_response.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

/// The background engine's composition (F25-T05) over a real (in-memory)
/// database — the same Drift repository and scheduler the app builds, so a
/// wiring mistake there shows up here rather than only on a device.
void main() {
  late AppDatabase db;
  late DriftRemindersRepository repository;
  late FakeLocalNotificationsPort notifications;
  // Whole seconds: Drift stores a time to the second (and reads it back as
  // local time), so the snoozed alert is compared as an instant below.
  final now = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );

  setUp(() {
    db = memoryDatabase();
    repository = DriftRemindersRepository(db.remindersDao);
    notifications = FakeLocalNotificationsPort();
  });
  tearDown(() => db.close());

  Future<Reminder> createReminder() async {
    final eventDay = now.add(const Duration(days: 3));
    final created = await repository.createReminder(
      title: 'دفع فاتورة الكهرباء',
      eventDate: DateTime(eventDay.year, eventDay.month, eventDay.day),
      eventMinuteOfDay: 600,
      isManual: true,
      alertTimes: [now.add(const Duration(days: 2))],
    );
    return (created as Ok<Reminder, Object>).value;
  }

  Future<List<Reminder>> pending() async =>
      (await repository.pendingReminders() as Ok<List<Reminder>, Object>).value;

  Future<void> run(String reminderId, ReminderNotificationAction action) =>
      runReminderNotificationAction(
        ReminderNotificationActionChosen(reminderId, action),
        database: db,
        notifications: notifications,
        now: () => now,
      );

  test('«تم» completes the reminder and leaves nothing scheduled', () async {
    final reminder = await createReminder();
    notifications.scheduled[notificationIdOf(reminder.alerts.single.id)] = (
      'already scheduled',
      null,
    );

    await run(reminder.id, ReminderNotificationAction.complete);

    expect(await pending(), isEmpty);
    expect(notifications.scheduled, isEmpty);
  });

  test('«أجّل ساعة» moves the reminder to one alert an hour from now, '
      'and schedules it with the OS', () async {
    final reminder = await createReminder();

    await run(reminder.id, ReminderNotificationAction.snooze);

    final snoozed = (await pending()).single;
    final alert = snoozed.alerts.single;
    expect(alert.scheduledAt.toUtc(), now.add(const Duration(hours: 1)));
    final id = notificationIdOf(alert.id);
    expect(notifications.scheduledAt[id], alert.scheduledAt);
    expect(notifications.payloads[id], reminder.id);
  });

  test('the snoozed notification keeps details hidden by default', () async {
    final reminder = await createReminder();

    await run(reminder.id, ReminderNotificationAction.snooze);

    final (title, _) = notifications.scheduled.values.single;
    expect(title, isNot(contains('فاتورة')));
  });

  test('a reminder already completed in the app stays completed', () async {
    final reminder = await createReminder();
    await repository.completeReminder(reminder.id);

    await run(reminder.id, ReminderNotificationAction.snooze);

    expect(await pending(), isEmpty);
    expect(notifications.scheduled, isEmpty);
  });
}
