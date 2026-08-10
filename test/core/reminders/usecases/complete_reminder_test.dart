import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late CompleteReminder useCase;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    useCase = CompleteReminder(repository, scheduler);
  });
  tearDown(() => repository.dispose());

  test('delegates to the repository', () async {
    final result = await useCase('r1');

    expect(result.isOk, isTrue);
    expect(repository.lastCompletedId, 'r1');
  });

  test('reconciles the scheduler on success', () async {
    await useCase('r1');

    expect(scheduler.reconcileCount, 1);
  });

  test('does not reconcile when the write fails', () async {
    repository.completeOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase('r1');

    expect(result.isErr, isTrue);
    expect(scheduler.reconcileCount, 0);
  });
}
