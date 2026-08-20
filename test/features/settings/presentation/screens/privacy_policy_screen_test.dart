import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/settings/presentation/screens/privacy_policy_screen.dart';

import '../../../../support/mirrored_icon.dart';
import '../../../../support/pump_app.dart';

// F11-T12: the settings screen's «سياسة الخصوصية» row opens this — the same
// four promises `PrivacyScreen` makes on first run, read back with a back
// control instead of a CTA.
void main() {
  const ar = ArStrings();
  const en = EnStrings();

  testWidgets('shows the title and all four privacy promises', (tester) async {
    await pumpApp(tester, const PrivacyPolicyScreen());

    expect(find.text(ar.settingsPrivacyPolicyLabel), findsOneWidget);
    expect(find.text(ar.privacyTitle), findsOneWidget);
    expect(find.text(ar.privacyPointExtractText), findsOneWidget);
    expect(find.text(ar.privacyPointTextOnly), findsOneWidget);
    expect(find.text(ar.privacyPointImageOptIn), findsOneWidget);
    expect(find.text(ar.privacyPointDeleteAnytime), findsOneWidget);
  });

  testWidgets('shows no CTA — agreeing already happened on first run', (
    tester,
  ) async {
    await pumpApp(tester, const PrivacyPolicyScreen());

    expect(find.text(ar.privacyAgree), findsNothing);
  });

  testWidgets('tapping back calls onClose', (tester) async {
    var closed = false;
    await pumpApp(tester, PrivacyPolicyScreen(onClose: () => closed = true));

    await tester.tap(find.byTooltip(ar.analysisResultBackLabel));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('renders in English, left-to-right', (tester) async {
    await pumpApp(
      tester,
      const PrivacyPolicyScreen(),
      locale: AppLocalizations.english,
    );

    expect(find.text(en.settingsPrivacyPolicyLabel), findsOneWidget);
    expect(find.text(en.privacyTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(PrivacyPolicyScreen))),
      TextDirection.ltr,
    );
    // F12-T03: the back icon is drawn once for the Arabic default and
    // mirrored by hand under LTR — confirms it actually flips here rather
    // than pointing the wrong way in English.
    expect(
      mirrorScaleX(tester, StrokeGlyph.arrowBack),
      -1,
      reason: 'LTR: mirrored to point left',
    );
  });

  testWidgets('survives large text without overflowing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const PrivacyPolicyScreen(),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(ar.settingsPrivacyPolicyLabel), findsOneWidget);
  });
}
