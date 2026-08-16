import '../database/app_database.dart';

/// Persists the user's «استكمال القراءة من آخر مكان» choice (F11-T07).
abstract interface class ResumeReadingEnabledStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the default for that case, not this store.
  Future<bool?> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

/// [ResumeReadingEnabledStore] backed by the Drift `app_settings` table — the
/// same key/value table [DriftAnalysisConsentStore] uses for its own bool.
final class DriftResumeReadingEnabledStore
    implements ResumeReadingEnabledStore {
  const DriftResumeReadingEnabledStore(this._db);

  static const String _key = 'resume_reading_enabled';

  final AppDatabase _db;

  @override
  Future<bool?> readEnabled() async {
    final value = await _db.getSetting(_key);
    return value == null ? null : value == 'true';
  }

  @override
  Future<void> writeEnabled(bool enabled) =>
      _db.setSetting(_key, enabled.toString());
}
