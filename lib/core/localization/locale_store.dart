import '../database/app_database.dart';

/// Persists the user's chosen language across launches.
abstract interface class LocaleStore {
  Future<String?> readLanguageCode();
  Future<void> writeLanguageCode(String code);
}

/// [LocaleStore] backed by the Drift `app_settings` table.
final class DriftLocaleStore implements LocaleStore {
  const DriftLocaleStore(this._db);

  static const String _key = 'locale';

  final AppDatabase _db;

  @override
  Future<String?> readLanguageCode() => _db.getSetting(_key);

  @override
  Future<void> writeLanguageCode(String code) => _db.setSetting(_key, code);
}
