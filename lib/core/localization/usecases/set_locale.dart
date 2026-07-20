import '../locale_store.dart';

/// Persists the user's chosen language code.
final class SetLocale {
  const SetLocale(this._store);

  final LocaleStore _store;

  Future<void> call(String languageCode) =>
      _store.writeLanguageCode(languageCode);
}
