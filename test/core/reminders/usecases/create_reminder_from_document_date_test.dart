import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/create_reminder_from_document_date.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late FakeReminderScheduler scheduler;
  late CreateReminderFromDocumentDate useCase;

  setUp(() {
    repository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    useCase = CreateReminderFromDocumentDate(repository, scheduler);
  });
  tearDown(() => repository.dispose());

  test(
    'delegates to the repository with isManual false and the document id',
    () async {
      final result = await useCase(
        documentId: 'doc-1',
        title: 'دفع فاتورة الكهرباء',
        eventDate: DateTime(2026, 8, 25),
        eventMinuteOfDay: 600,
        alertTimes: [DateTime.utc(2026, 8, 24, 8)],
      );

      expect(result.isOk, isTrue);
      expect(repository.lastCreatedIsManual, isFalse);
      expect(repository.lastCreatedDocumentId, 'doc-1');
    },
  );

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
