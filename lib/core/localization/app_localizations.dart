import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_strings.dart';
import 'ar_strings.dart';
import 'en_strings.dart';

/// Central localization configuration and access point.
///
/// No code generation: [AppStringsDelegate] simply returns the right hand-
/// written [AppStrings] implementation for the active locale. Text direction
/// follows the locale automatically (Arabic → RTL, English → LTR).
abstract final class AppLocalizations {
  static const Locale arabic = Locale('ar');
  static const Locale english = Locale('en');

  static const List<Locale> supportedLocales = [arabic, english];

  static const List<LocalizationsDelegate<Object?>> delegates = [
    AppStringsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Resolves an unsupported/null device locale to a supported one (Arabic).
  static Locale resolve(Locale? locale, Iterable<Locale> supported) {
    if (locale != null) {
      for (final s in supported) {
        if (s.languageCode == locale.languageCode) return s;
      }
    }
    return arabic;
  }
}

/// [LocalizationsDelegate] that loads the correct [AppStrings] for a locale.
class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  /// Resolves **synchronously**, and must keep doing so.
  ///
  /// [Localizations] renders an empty `Container` — the bare window background,
  /// no app UI at all — until every delegate's future has completed. A
  /// [SynchronousFuture] completes within the same frame, so the first frame
  /// paints the app; a plain `async` body (which always returns a real `Future`,
  /// however trivial its work) costs a guaranteed blank frame at launch instead.
  /// That is why Flutter's own `GlobalMaterialLocalizations.delegate` returns one
  /// too, and why this must not be turned back into an `async` function.
  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture<AppStrings>(
    locale.languageCode == 'ar' ? const ArStrings() : const EnStrings(),
  );

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

/// Convenience accessor: `context.strings.appName`.
extension AppStringsX on BuildContext {
  AppStrings get strings => Localizations.of<AppStrings>(this, AppStrings)!;
}
