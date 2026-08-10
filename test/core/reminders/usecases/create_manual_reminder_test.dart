import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/create_manual_reminder.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late CreateManualReminder useCase;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    useCase = CreateManualReminder(repository, scheduler);
  });
  tearDown(() => repository.dispose());

  test('delegates to the repository with isManual true', () async {
    final result = await useCase(
      title: 'دفع فاتورة الكهرباء',
      eventDate: DateTime(2026, 8, 25),
      eventMinuteOfDay: 600,
      alertTimes: [DateTime.utc(2026, 8, 24, 8)],
    );

    expect(result.isOk, isTrue);
    expect(repository.lastCreatedIsManual, isTrue);
    expect(repository.lastCreatedTitle, 'دفع فاتورة الكهرباء');
  });

  test('reconciles the scheduler on success', () async {
    await useCase(
      title: 'دفع فاتورة الكهرباء',
      eventDate: DateTime(2026, 8, 25),
      eventMinuteOfDay: 600,
      alertTimes: [DateTime.utc(2026, 8, 24, 8)],
    );

    expect(scheduler.reconcileCount, 1);
  });

  test('does not reconcile when the write fails', () async {
    repository.createOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase(
      title: 'دفع فاتورة الكهرباء',
      eventDate: DateTime(2026, 8, 25),
      eventMinuteOfDay: 600,
      alertTimes: [DateTime.utc(2026, 8, 24, 8)],
    );

    expect(result.isErr, isTrue);
    expect(scheduler.reconcileCount, 0);
  });
}
