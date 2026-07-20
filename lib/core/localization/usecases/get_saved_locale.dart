import '../locale_store.dart';

/// Reads the persisted language code, or `null` if the user never chose one.
final class GetSavedLocale {
  const GetSavedLocale(this._store);

  final LocaleStore _store;

  Future<String?> call() => _store.readLanguageCode();
}
