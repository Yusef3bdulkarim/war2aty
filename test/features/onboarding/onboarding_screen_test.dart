import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:war2aty/features/onboarding/presentation/widgets/primary_cta.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('OnboardingScreen', () {
    testWidgets('shows the heading, lead copy and all four kind cards', (
      tester,
    ) async {
      await pumpApp(tester, const OnboardingScreen());

      expect(find.text(ar.onboardingTitle), findsOneWidget);
      expect(find.text(ar.onboardingSubtitle), findsOneWidget);
      expect(find.text(ar.onboardingKindAppointment), findsOneWidget);
      expect(find.text(ar.onboardingKindInvoice), findsOneWidget);
      expect(find.text(ar.onboardingKindGovernment), findsOneWidget);
      expect(find.text(ar.onboardingKindEducation), findsOneWidget);
      expect(find.text(ar.onboardingStart), findsOneWidget);
    });

    testWidgets('each card carries its own icon', (tester) async {
      await pumpApp(tester, const OnboardingScreen());

      final glyphs = tester
          .widgetList<StrokeIcon>(find.byType(StrokeIcon))
          .map((icon) => icon.glyph)
          .toList();

      expect(glyphs, documentKindGlyphs);
    });

    testWidgets('lays out right-to-left in Arabic', (tester) async {
      await pumpApp(tester, const OnboardingScreen());

      expect(
        Directionality.of(tester.element(find.byType(PrimaryCta))),
        TextDirection.rtl,
      );
    });

    testWidgets('renders in English, left-to-right', (tester) async {
      await pumpApp(
        tester,
        const OnboardingScreen(),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.onboardingTitle), findsOneWidget);
      expect(find.text(en.onboardingKindGovernment), findsOneWidget);
      expect(find.text(en.onboardingStart), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(PrimaryCta))),
        TextDirection.ltr,
      );
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        const OnboardingScreen(),
        // The largest step the app has to support.
        textScaler: const TextScaler.linear(2),
      );

      // No RenderFlex overflow was thrown, and the CTA is still on screen.
      expect(tester.takeException(), isNull);
      expect(find.byType(PrimaryCta), findsOneWidget);
      expect(find.text(ar.onboardingStart), findsOneWidget);
    });

    testWidgets('the content scrolls when it does not fit', (tester) async {
      tester.view.physicalSize = const Size(390, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(tester, const OnboardingScreen());

      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the call to action is a single tappable button', (
      tester,
    ) async {
      await pumpApp(tester, const OnboardingScreen());

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });
  });
}
