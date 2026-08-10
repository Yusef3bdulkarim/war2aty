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
import 'package:war2aty/core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  const ar = ArStrings();
  late FakeRemindersRepository repository;
  late FakeLocalNotificationsPort notifications;
  late FakeNotificationPrivacyStore privacyStore;
  late LocalNotificationsReminderScheduler scheduler;

  setUp(() {
    repository = FakeRemindersRepository();
    notifications = FakeLocalNotificationsPort();
    privacyStore = FakeNotificationPrivacyStore();
    scheduler = LocalNotificationsReminderScheduler(
      notifications,
      repository,
      GetSavedLocale(FakeLocaleStore()),
      GetHideSensitiveNotificationDetails(privacyStore),
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

  group('notification privacy (F09-T14)', () {
    test('hides the reminder\'s title by default', () async {
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      repository.pendingOutcome = Ok([
        fakeReminder(alertTimes: [future]),
      ]);

      await scheduler.reconcile();

      final (title, _) = notifications.scheduled.values.single;
      expect(title, ar.reminderNotificationGenericTitle);
    });

    test('still hides once the setting is explicitly turned on', () async {
      await privacyStore.writeHideSensitiveDetails(true);
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      repository.pendingOutcome = Ok([
        fakeReminder(alertTimes: [future]),
      ]);

      await scheduler.reconcile();

      final (title, _) = notifications.scheduled.values.single;
      expect(title, ar.reminderNotificationGenericTitle);
    });

    test('shows the real title once the user turns it off', () async {
      await privacyStore.writeHideSensitiveDetails(false);
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      repository.pendingOutcome = Ok([
        fakeReminder(alertTimes: [future]),
      ]);

      await scheduler.reconcile();

      final (title, _) = notifications.scheduled.values.single;
      expect(title, 'دفع فاتورة الكهرباء');
    });
  });

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

  group('restart (F09-T13)', () {
    // The plugin's own scheduled alarms and the app's Dart-side database
    // both outlive an app restart, but nothing in this process's memory
    // does — a fresh `LocalNotificationsReminderScheduler`, built the same
    // way `_buildLaunchSteps` builds one at every launch, is the only
    // realistic stand-in for that. These tests share [notifications] and
    // [repository] across two scheduler instances to model exactly that:
    // whatever state survived the restart, reconciling from a cold start
    // still converges the OS to what the database says.
    late LocalNotificationsReminderScheduler freshScheduler;

    LocalNotificationsReminderScheduler bootScheduler() =>
        LocalNotificationsReminderScheduler(
          notifications,
          repository,
          GetSavedLocale(FakeLocaleStore()),
          GetHideSensitiveNotificationDetails(privacyStore),
        );

    test('schedules a reminder the previous process never got to', () async {
      // Simulates a reminder that was created, but the app was killed
      // before its own post-write reconcile ran — never reached the OS.
      final future = DateTime.now().toUtc().add(const Duration(days: 1));
      repository.pendingOutcome = Ok([
        fakeReminder(alertTimes: [future]),
      ]);

      freshScheduler = bootScheduler();
      final outcome = await freshScheduler.reconcile();

      expect(outcome, const Ok<int, AppFailure>(1));
      expect(notifications.scheduled, hasLength(1));
    });

    test(
      'cancels the OS alarm for a reminder deleted while the app was closed',
      () async {
        // "While closed" here means: whatever the previous process last
        // scheduled is still sitting in `notifications` (the plugin's own
        // state persists across restarts), but the database — read fresh —
        // no longer lists the reminder at all.
        final future = DateTime.now().toUtc().add(const Duration(days: 1));
        final reminder = fakeReminder(alertTimes: [future]);
        final id = notificationIdOf(reminder.alerts.single.id);
        notifications.scheduled[id] = ('دفع فاتورة الكهرباء', null);
        repository.pendingOutcome = const Ok([]);

        freshScheduler = bootScheduler();
        await freshScheduler.reconcile();

        expect(notifications.scheduled, isEmpty);
      },
    );

    test('a snooze recorded moments before a crash still reaches the OS on '
        'the next launch', () async {
      // The DB write from a snooze (F09-T12) always lands before its
      // fire-and-forget reconcile gets a chance to run — a crash in
      // between must not lose it, since the very next launch reconciles
      // from the database again.
      final original = DateTime.now().toUtc().add(const Duration(days: 3));
      final snoozed = DateTime.now().toUtc().add(const Duration(hours: 1));
      final oldId = notificationIdOf('r1-a0');
      notifications.scheduled[oldId] = ('دفع فاتورة الكهرباء', null);
      repository.pendingOutcome = Ok([
        Reminder(
          id: 'r1',
          title: 'دفع فاتورة الكهرباء',
          eventDate: DateTime(2026, 8, 25),
          status: ReminderStatus.pending,
          isManual: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          alerts: [
            // The snooze replaced the old alert row outright (matches
            // `DriftRemindersRepository.snoozeReminder`), so only the new
            // one is in the database the fresh process reads.
            ReminderAlert(
              id: 'r1-a1',
              reminderId: 'r1',
              scheduledAt: snoozed,
              status: ReminderAlertStatus.scheduled,
            ),
          ],
        ),
      ]);
      // Sanity: the old alert time is not part of this reminder's alerts
      // any more, only its now-stale OS entry remains.
      expect(original, isNot(snoozed));

      freshScheduler = bootScheduler();
      await freshScheduler.reconcile();

      expect(notifications.scheduled.containsKey(oldId), isFalse);
      final newId = notificationIdOf('r1-a1');
      expect(notifications.scheduled.containsKey(newId), isTrue);
    });
  });
}
