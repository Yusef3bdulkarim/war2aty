import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:war2aty/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:war2aty/features/onboarding/presentation/widgets/primary_cta.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';
import '../../support/ui_audit.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  auditScreenLayout(
    'OnboardingScreen',
    (tester, locale, scaler) => pumpApp(
      tester,
      const OnboardingScreen(),
      locale: locale,
      textScaler: scaler,
    ),
  );

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

    // F35-T10. Until F35 this screen handed off to `PrivacyScreen`, which was
    // the ONLY caller of `OnboardingCubit.complete()`. F34 removes that
    // screen, so without this the first-run flag would never be set and
    // `_firstRunRedirect` would pin every launch on this page with no route to
    // Home — a bricked first run, from deleting a screen that looked
    // self-contained. This test is what stops that reopening.
    testWidgets('the call to action completes onboarding itself', (
      tester,
    ) async {
      final repository = FakeOnboardingRepository();
      final cubit = OnboardingCubit(
        hasSeenOnboarding: HasSeenOnboarding(repository),
        completeOnboarding: CompleteOnboarding(repository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state, const OnboardingRequired());

      await pumpApp(
        tester,
        BlocProvider<OnboardingCubit>.value(
          value: cubit,
          child: const OnboardingScreen(),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // The flag is persisted, and the gate the router watches has moved —
      // both halves matter: the state alone would not survive a relaunch, and
      // the write alone would not lift the redirect.
      expect(repository.seen, isTrue);
      expect(cubit.state, const OnboardingCompleted());
    });
  });
}
