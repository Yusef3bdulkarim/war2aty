import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_localizations.dart';
import 'usecases/get_saved_locale.dart';
import 'usecases/set_locale.dart';

/// Holds the active [Locale] and persists the user's choice.
///
/// Defaults to Arabic (RTL-first). [load] restores the saved language on
/// startup; [setLanguage] switches and persists it. Direction is derived from
/// the locale by the framework — no manual RTL/LTR handling needed. Depends on
/// use cases only, never on the store directly.
final class LocaleCubit extends Cubit<Locale> {
  LocaleCubit({
    required GetSavedLocale getSavedLocale,
    required SetLocale setLocale,
  }) : _getSavedLocale = getSavedLocale,
       _setLocale = setLocale,
       super(AppLocalizations.arabic);

  final GetSavedLocale _getSavedLocale;
  final SetLocale _setLocale;

  /// Restores the persisted language, if any.
  Future<void> load() async {
    final code = await _getSavedLocale();
    if (code != null && code != state.languageCode) {
      emit(Locale(code));
    }
  }

  /// Switches language and persists it.
  Future<void> setLanguage(String languageCode) async {
    if (languageCode == state.languageCode) return;
    await _setLocale(languageCode);
    emit(Locale(languageCode));
  }

  /// Reverts to the default locale in memory, without persisting anything —
  /// for «حذف كل بيانات التطبيق» (F11-T11), once its own `app_settings` row
  /// is already gone.
  ///
  /// Unlike [load], this doesn't need [GetSavedLocale] — the caller already
  /// knows the persisted choice was just cleared, and [GetSavedLocale] has no
  /// built-in fallback the way `GetTextSize`/`GetHighContrast` do, so a plain
  /// [load] here would leave the in-memory locale stuck on whatever it was
  /// until the next full app restart.
  void resetToDefault() {
    if (state == AppLocalizations.arabic) return;
    emit(AppLocalizations.arabic);
  }
}
