import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/theme/app_theme.dart';

/// Pumps [child] inside a fully-configured app shell: theme, Cairo, the
/// localization delegates, and a locale (Arabic by default → RTL). Use this
/// for widget tests so screens see the same environment as the real app.
/// Set [settle] to false for screens with a continuously repeating animation —
/// `pumpAndSettle` never returns while one is running.
/// Pass [textScaler] to check a screen under Large Text (a project
/// requirement for every new screen).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocalizations.arabic,
  bool settle = true,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.delegates,
      home: textScaler == null
          ? child
          : Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child,
              ),
            ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
