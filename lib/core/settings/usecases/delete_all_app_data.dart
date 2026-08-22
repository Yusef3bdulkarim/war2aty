import '../../documents/usecases/delete_all_documents.dart';
import '../../error/app_failure.dart';
import '../../reminders/usecases/delete_all_reminders.dart';
import '../../result/result.dart';
import '../../storage/analysis_session_storage.dart';
import '../app_settings_repository.dart';

/// Wipes everything «حذف كل بيانات التطبيق» promises (F11-T11): every
/// document, every reminder, every setting/usage-cache row, and any leftover
/// scan-session temp file.
///
/// Composes the narrower delete-all actions rather than talking to
/// [DocumentsRepository]/[RemindersRepository]/`ReminderScheduler` directly,
/// so each cascade/reconcile rule stays defined in exactly one place. Stops
/// at the first failure — pressing on regardless could leave the user with
/// "your data was wiped" feedback next to data that, in fact, wasn't.
///
/// Never touches secure storage — see [AppSettingsRepository].
final class DeleteAllAppData {
  const DeleteAllAppData(
    this._deleteAllDocuments,
    this._deleteAllReminders,
    this._settingsRepository,
    this._sessionStorage,
  );

  final DeleteAllDocuments _deleteAllDocuments;
  final DeleteAllReminders _deleteAllReminders;
  final AppSettingsRepository _settingsRepository;
  final AnalysisSessionStorage _sessionStorage;

  Future<Result<void, AppFailure>> call() async {
    final documents = await _deleteAllDocuments();
    if (documents.isErr) return documents;
    final reminders = await _deleteAllReminders();
    if (reminders.isErr) return reminders;
    final settings = await _settingsRepository.clearAllSettingsAndUsageCache();

    // Best-effort, same reasoning as the launch-time sweep this duplicates
    // (F12-T06 — privacy §7): nothing can be mid-analysis while the user is
    // confirming a destructive settings action, so any leftover
    // `analysis_sessions/*` folder is by definition stale — no reason to
    // make the user wait for the next cold start to actually see it gone.
    // Deliberately not part of the returned [Result]: a wipe the user
    // already confirmed must not be reported as failed over stale cache.
    await _sessionStorage.deleteStaleSessions();

    return settings;
  }
}
