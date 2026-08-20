import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/delete_all_reminders.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

// F11-T11: settings' «حذف كل التذكيرات».
void main() {
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late DeleteAllReminders useCase;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    useCase = DeleteAllReminders(repository, scheduler);
  });
  tearDown(() => repository.dispose());

  test('delegates to the repository', () async {
    final result = await useCase();

    expect(result.isOk, isTrue);
    expect(repository.deleteAllCalled, isTrue);
  });

  test('reconciles the scheduler on success', () async {
    await useCase();

    expect(scheduler.reconcileCount, 1);
  });

  test('does not reconcile when the write fails', () async {
    repository.deleteAllOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase();

    expect(result.isErr, isTrue);
    expect(scheduler.reconcileCount, 0);
  });
}
