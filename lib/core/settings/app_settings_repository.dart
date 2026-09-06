import '../error/app_failure.dart';
import '../result/result.dart';

/// Clears every locally-persisted setting and usage-cache row in one call —
/// settings' «حذف كل بيانات التطبيق» (F11-T11).
///
/// Lives in `core/settings/` rather than `core/documents/` or
/// `core/reminders/`: this action spans documents, reminders, and settings,
/// and belongs to none of them alone.
abstract interface class AppSettingsRepository {
  /// Deletes every row of `app_settings` and `usage_cache`. Every `Get*` use
  /// case already falls back to its documented default once a setting is
  /// unset, so nothing here writes a default value back.
  ///
  /// Preserves the onboarding-seen flag: it is a technical first-run gate,
  /// not a user preference with a friendly default — losing it would send a
  /// returning user back to onboarding on their next launch, unprompted by
  /// this action.
  ///
  /// Never touches secure storage — installationId, the anonymous Supabase
  /// session, and the document-encryption key survive a full wipe by product
  /// decision (CLAUDE.md §7).
  Future<Result<void, AppFailure>> clearAllSettingsAndUsageCache();
}
