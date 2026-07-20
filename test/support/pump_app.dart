import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/theme/app_theme.dart';

/// Pumps [child] inside a fully-configured app shell: theme, Cairo, the
/// localization delegates, and a locale (Arabic by default → RTL). Use this
/// for widget tests so screens see the same environment as the real app.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocalizations.arabic,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.delegates,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
