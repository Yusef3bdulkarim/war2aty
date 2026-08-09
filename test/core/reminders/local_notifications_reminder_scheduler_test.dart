import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/reminders/flutter_local_notifications_reminder_scheduler.dart';
import 'package:war2aty/core/reminders/notification_id.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_alert.dart';
import 'package:war2aty/core/reminders/reminder_alert_status.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  const ar = ArStrings();
  late FakeRemindersRepository repository;
  late FakeLocalNotificationsPort notifications;
  late LocalNotificationsReminderScheduler scheduler;

  setUp(() {
    repository = FakeRemindersRepository();
    notifications = FakeLocalNotificationsPort();
    scheduler = LocalNotificationsReminderScheduler(
      notifications,
      repository,
      GetSavedLocale(FakeLocaleStore()),
    );
  });

  test('schedules every future alert of every pending reminder', () async {
    final future1 = DateTime.now().toUtc().add(const Duration(days: 1));
    final future2 = DateTime.now().toUtc().add(const Duration(days: 2));
    repository.pendingOutcome = Ok([
      fakeReminder(alertTimes: [future1]),
      fakeReminder(id: 'r2', alertTimes: [future2]),
    ]);

    final outcome = await scheduler.reconcile();

    expect(outcome, const Ok<int, AppFailure>(2));
    expect(notifications.scheduled, hasLength(2));
  });

  test('never schedules an alert already in the past', () async {
    final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
    repository.pendingOutcome = Ok([
      fakeReminder(alertTimes: [past]),
    ]);

    final outcome = await scheduler.reconcile();

    expect(outcome, const Ok<int, AppFailure>(0));
    expect(notifications.scheduled, isEmpty);
  });

  test('skips a cancelled alert', () async {
    final future = DateTime.now().toUtc().add(const Duration(days: 1));
    final reminder = Reminder(
      id: 'r1',
      title: 'دفع فاتورة الكهرباء',
      eventDate: DateTime(2026, 8, 25),
      status: ReminderStatus.pending,
      isManual: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      alerts: [
        ReminderAlert(
          id: 'a1',
          reminderId: 'r1',
          scheduledAt: future,
          status: ReminderAlertStatus.cancelled,
        ),
      ],
    );
    repository.pendingOutcome = Ok([reminder]);

    final outcome = await scheduler.reconcile();

    expect(outcome, const Ok<int, AppFailure>(0));
  });

  test('cancels an OS notification with no matching due alert', () async {
    notifications.scheduled[999] = ('stale', null);
    repository.pendingOutcome = const Ok([]);

    await scheduler.reconcile();

    expect(notifications.scheduled, isEmpty);
  });

  test('leaves a still-valid OS notification alone', () async {
    final future = DateTime.now().toUtc().add(const Duration(days: 1));
    final reminder = fakeReminder(alertTimes: [future]);
    final id = notificationIdOf(reminder.alerts.single.id);
    notifications.scheduled[id] = ('already there', null);
    repository.pendingOutcome = Ok([reminder]);

    await scheduler.reconcile();

    expect(notifications.scheduled[id], isNotNull);
  });

  test('marks a scheduling failure as failed, not scheduled', () async {
    final future = DateTime.now().toUtc().add(const Duration(days: 1));
    final reminder = fakeReminder(alertTimes: [future]);
    final id = notificationIdOf(reminder.alerts.single.id);
    notifications.failingIds.add(id);
    repository.pendingOutcome = Ok([reminder]);

    await scheduler.reconcile();

    expect(repository.lastAlertStatus, ReminderAlertStatus.failed);
  });

  test(
    'hides the reminder\'s title by default (F09-T14 not wired yet)',
    () async {
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      repository.pendingOutcome = Ok([
        fakeReminder(alertTimes: [future]),
      ]);

      await scheduler.reconcile();

      final (title, _) = notifications.scheduled.values.single;
      expect(title, ar.reminderNotificationGenericTitle);
    },
  );

  test(
    'marks a past scheduled alert delivered (best-effort bookkeeping)',
    () async {
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      repository.pendingOutcome = Ok([
        fakeReminder(alertTimes: [past]),
      ]);

      await scheduler.reconcile();

      expect(repository.lastAlertStatus, ReminderAlertStatus.delivered);
    },
  );

  test('a repository failure surfaces as the reconcile outcome', () async {
    repository.pendingOutcome = const Err(LocalDatabaseFailure());

    final outcome = await scheduler.reconcile();

    expect(outcome.isErr, isTrue);
  });
}
