import '../database/app_database.dart';
import 'processing_mode.dart';

/// Persists the user's «طريقة معالجة الأوراق» choice (F11-T03) — whether
/// captured papers go through smart analysis (OCR + AI) or stop at text
/// extraction (OCR only).
abstract interface class ProcessingModeStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the default for that case, not this store.
  Future<ProcessingMode?> readMode();

  Future<void> writeMode(ProcessingMode mode);
}

/// [ProcessingModeStore] backed by the Drift `app_settings` table — the same
/// key/value table [DriftAnalysisConsentStore] and [DriftLocaleStore] use.
final class DriftProcessingModeStore implements ProcessingModeStore {
  const DriftProcessingModeStore(this._db);

  static const String _key = 'processing_mode';

  final AppDatabase _db;

  @override
  Future<ProcessingMode?> readMode() async {
    final value = await _db.getSetting(_key);
    if (value == null) return null;
    // Match the enum's [name] — the same string [writeMode] persists.
    for (final mode in ProcessingMode.values) {
      if (mode.name == value) return mode;
    }
    // An unrecognised value (future enum member?) falls back to null so the
    // caller applies the default rather than crashing.
    return null;
  }

  @override
  Future<void> writeMode(ProcessingMode mode) =>
      _db.setSetting(_key, mode.name);
}
