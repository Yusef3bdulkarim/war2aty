import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/settings/presentation/screens/settings_screen.dart';

import '../../../../support/pump_app.dart';

// F11-T01: the settings scaffold, wired in place of `PlaceholderTab`.
void main() {
  const ar = ArStrings();

  testWidgets('shows the page heading', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    expect(find.text(ar.navSettings), findsOneWidget);
  });

  testWidgets('the heading is announced as a header', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    expect(
      tester.getSemantics(find.text(ar.navSettings)),
      isSemantics(isHeader: true),
    );
  });

  testWidgets('lays out under Large Text and in English', (tester) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      locale: AppLocalizations.english,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text(const EnStrings().navSettings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
