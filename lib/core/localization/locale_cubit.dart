import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_localizations.dart';
import 'locale_store.dart';

/// Holds the active [Locale] and persists the user's choice.
///
/// Defaults to Arabic (RTL-first). [load] restores the saved language on
/// startup; [setLanguage] switches and persists it. Direction is derived from
/// the locale by the framework — no manual RTL/LTR handling needed.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._store) : super(AppLocalizations.arabic);

  final LocaleStore _store;

  /// Restores the persisted language, if any.
  Future<void> load() async {
    final code = await _store.readLanguageCode();
    if (code != null && code != state.languageCode) {
      emit(Locale(code));
    }
  }

  /// Switches language and persists it.
  Future<void> setLanguage(String languageCode) async {
    if (languageCode == state.languageCode) return;
    await _store.writeLanguageCode(languageCode);
    emit(Locale(languageCode));
  }
}
