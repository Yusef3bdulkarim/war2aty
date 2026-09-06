import '../database/app_database.dart';
import 'text_size.dart';

/// Persists the user's chosen text size (F11-T05).
abstract interface class TextSizeStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the default for that case, not this store.
  Future<TextSize?> readSize();

  Future<void> writeSize(TextSize size);
}

/// [TextSizeStore] backed by the Drift `app_settings` table — the same
/// key/value table [DriftProcessingModeStore] and [DriftLocaleStore] use.
final class DriftTextSizeStore implements TextSizeStore {
  const DriftTextSizeStore(this._db);

  static const String _key = 'text_size';

  final AppDatabase _db;

  @override
  Future<TextSize?> readSize() async {
    final value = await _db.getSetting(_key);
    if (value == null) return null;
    for (final size in TextSize.values) {
      if (size.name == value) return size;
    }
    // An unrecognised value (future enum member?) falls back to null so the
    // caller applies the default rather than crashing.
    return null;
  }

  @override
  Future<void> writeSize(TextSize size) => _db.setSetting(_key, size.name);
}
