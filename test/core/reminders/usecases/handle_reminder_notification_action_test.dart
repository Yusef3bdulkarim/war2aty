import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/reminder_notification_response.dart';
import 'package:war2aty/core/reminders/usecases/handle_reminder_notification_action.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 7);
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late HandleReminderNotificationAction useCase;

  setUp(() {
    repository = FakeRemindersRepository()
      ..pendingOutcome = Ok([fakeReminder()]);
    scheduler = FakeReminderScheduler();
    useCase = HandleReminderNotificationAction(
      repository,
      scheduler,
      now: () => now,
    );
  });
  tearDown(() => repository.dispose());

  test('«تم» completes the reminder', () async {
    final result = await useCase('r1', ReminderNotificationAction.complete);

    expect(result.isOk, isTrue);
    expect(repository.lastCompletedId, 'r1');
    expect(repository.lastSnoozedId, isNull);
  });

  test('«أجّل ساعة» snoozes it to an hour from now', () async {
    final result = await useCase('r1', ReminderNotificationAction.snooze);

    expect(result.isOk, isTrue);
    expect(repository.lastSnoozedId, 'r1');
    expect(repository.lastSnoozedTo, now.add(const Duration(hours: 1)));
    expect(repository.lastCompletedId, isNull);
  });

  test('awaits a reconcile after the write', () async {
    await useCase('r1', ReminderNotificationAction.snooze);

    expect(scheduler.reconcileCount, 1);
  });

  test('a reminder no longer pending is left alone', () async {
    // Completed or deleted in the app after its notification fired.
    repository.pendingOutcome = Ok([fakeReminder(id: 'other')]);

    final result = await useCase('r1', ReminderNotificationAction.snooze);

    expect(result.isOk, isTrue);
    expect(repository.lastSnoozedId, isNull);
    expect(repository.lastCompletedId, isNull);
    expect(scheduler.reconcileCount, 0);
  });

  test('a failed read surfaces, and nothing is written', () async {
    repository.pendingOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase('r1', ReminderNotificationAction.complete);

    expect(result.isErr, isTrue);
    expect(repository.lastCompletedId, isNull);
  });

  test('a failed write surfaces and skips the reconcile', () async {
    repository.completeOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase('r1', ReminderNotificationAction.complete);

    expect(result.isErr, isTrue);
    expect(scheduler.reconcileCount, 0);
  });

  test('a failed reconcile does not fail the action', () async {
    scheduler.outcome = const Err(LocalDatabaseFailure());

    final result = await useCase('r1', ReminderNotificationAction.complete);

    expect(result.isOk, isTrue);
  });
}
