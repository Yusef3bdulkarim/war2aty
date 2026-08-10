import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late SnoozeReminder useCase;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    useCase = SnoozeReminder(repository, scheduler);
  });
  tearDown(() => repository.dispose());

  test('delegates to the repository with the new alert time', () async {
    final newTime = DateTime.utc(2026, 8, 26, 10);

    final result = await useCase('r1', newTime);

    expect(result.isOk, isTrue);
    expect(repository.lastSnoozedId, 'r1');
    expect(repository.lastSnoozedTo, newTime);
  });

  test('reconciles the scheduler on success', () async {
    await useCase('r1', DateTime.utc(2026, 8, 26, 10));

    expect(scheduler.reconcileCount, 1);
  });

  test('does not reconcile when the write fails', () async {
    repository.snoozeOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase('r1', DateTime.utc(2026, 8, 26, 10));

    expect(result.isErr, isTrue);
    expect(scheduler.reconcileCount, 0);
  });
}
