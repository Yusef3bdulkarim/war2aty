import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/delete_all_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/delete_all_reminders.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/settings/usecases/delete_all_app_data.dart';

import '../../../support/fakes.dart';

// F11-T11: settings' «حذف كل بيانات التطبيق» — composes the narrower
// delete-all actions.
void main() {
  late FakeDocumentsRepository documentsRepository;
  late FakeRemindersRepository remindersRepository;
  late FakeReminderScheduler scheduler;
  late FakeAppSettingsRepository settingsRepository;
  late FakeAnalysisSessionStorage sessionStorage;
  late DeleteAllAppData useCase;

  setUp(() {
    documentsRepository = FakeDocumentsRepository();
    remindersRepository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    settingsRepository = FakeAppSettingsRepository();
    sessionStorage = FakeAnalysisSessionStorage();
    useCase = DeleteAllAppData(
      DeleteAllDocuments(documentsRepository),
      DeleteAllReminders(remindersRepository, scheduler),
      settingsRepository,
      sessionStorage,
    );
  });
  tearDown(() => documentsRepository.dispose());

  test('deletes documents, reminders, and settings, in order', () async {
    final result = await useCase();

    expect(result.isOk, isTrue);
    expect(documentsRepository.deleteAllCalled, isTrue);
    expect(remindersRepository.deleteAllCalled, isTrue);
    expect(settingsRepository.clearCalled, isTrue);
  });

  test('stops after the documents step fails, without touching reminders or '
      'settings', () async {
    documentsRepository.deleteAllOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase();

    expect(result, const Err<void, AppFailure>(LocalDatabaseFailure()));
    expect(remindersRepository.deleteAllCalled, isFalse);
    expect(settingsRepository.clearCalled, isFalse);
  });

  test(
    'stops after the reminders step fails, without clearing settings',
    () async {
      remindersRepository.deleteAllOutcome = const Err(LocalDatabaseFailure());

      final result = await useCase();

      expect(result.isErr, isTrue);
      expect(documentsRepository.deleteAllCalled, isTrue);
      expect(settingsRepository.clearCalled, isFalse);
    },
  );

  test('surfaces a settings-clear failure', () async {
    settingsRepository.clearOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase();

    expect(result, const Err<void, AppFailure>(LocalDatabaseFailure()));
  });

  // F12-T06: a stale scan-session temp folder should not have to wait for
  // the next app launch once the user has explicitly wiped everything.
  test('also sweeps any leftover scan-session temp files', () async {
    await useCase();

    expect(sessionStorage.deleteStaleSessionsCallCount, 1);
  });
}
