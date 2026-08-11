import '../database/app_database.dart';

/// Persists the user's «تباين عالي» choice (F11-T06).
abstract interface class HighContrastStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the default for that case, not this store.
  Future<bool?> readEnabled();

  Future<void> writeEnabled(bool enabled);
}

/// [HighContrastStore] backed by the Drift `app_settings` table — the same
/// key/value table [DriftTextSizeStore] and [DriftAnalysisConsentStore] use.
final class DriftHighContrastStore implements HighContrastStore {
  const DriftHighContrastStore(this._db);

  static const String _key = 'high_contrast';

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
