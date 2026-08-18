import '../../documents/usecases/delete_all_documents.dart';
import '../../error/app_failure.dart';
import '../../reminders/usecases/delete_all_reminders.dart';
import '../../result/result.dart';
import '../app_settings_repository.dart';

/// Wipes everything «حذف كل بيانات التطبيق» promises (F11-T11): every
/// document, every reminder, and every setting/usage-cache row.
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
  );

  final DeleteAllDocuments _deleteAllDocuments;
  final DeleteAllReminders _deleteAllReminders;
  final AppSettingsRepository _settingsRepository;

  Future<Result<void, AppFailure>> call() async {
    final documents = await _deleteAllDocuments();
    if (documents.isErr) return documents;
    final reminders = await _deleteAllReminders();
    if (reminders.isErr) return reminders;
    return _settingsRepository.clearAllSettingsAndUsageCache();
  }
}
