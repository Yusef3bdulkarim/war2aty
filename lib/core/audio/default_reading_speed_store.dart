import '../database/app_database.dart';
import 'reading_speed.dart';

/// Persists the user's «سرعة القراءة الافتراضية» choice (F11-T07) — the
/// [ReadingSpeed] a fresh reading starts at until the user picks a different
/// one from the options sheet for that particular reading.
abstract interface class DefaultReadingSpeedStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the default for that case, not this store.
  Future<ReadingSpeed?> readSpeed();

  Future<void> writeSpeed(ReadingSpeed speed);
}

/// [DefaultReadingSpeedStore] backed by the Drift `app_settings` table — the
/// same key/value table [DriftAnalysisConsentStore]/[DriftProcessingModeStore]
/// use.
final class DriftDefaultReadingSpeedStore implements DefaultReadingSpeedStore {
  const DriftDefaultReadingSpeedStore(this._db);

  static const String _key = 'default_reading_speed';

  final AppDatabase _db;

  @override
  Future<ReadingSpeed?> readSpeed() async {
    final value = await _db.getSetting(_key);
    if (value == null) return null;
    // Match the enum's [name] — the same string [writeSpeed] persists.
    for (final speed in ReadingSpeed.values) {
      if (speed.name == value) return speed;
    }
    // An unrecognised value (future enum member?) falls back to null so the
    // caller applies the default rather than crashing.
    return null;
  }

  @override
  Future<void> writeSpeed(ReadingSpeed speed) =>
      _db.setSetting(_key, speed.name);
}
