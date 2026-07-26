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
import 'package:war2aty/features/onboarding/presentation/screens/privacy_screen.dart';
import 'package:war2aty/features/onboarding/presentation/widgets/primary_cta.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeOnboardingRepository repository;
  late OnboardingCubit cubit;

  setUp(() {
    repository = FakeOnboardingRepository();
    cubit = OnboardingCubit(
      hasSeenOnboarding: HasSeenOnboarding(repository),
      completeOnboarding: CompleteOnboarding(repository),
    );
  });

  tearDown(() => cubit.close());

  Future<void> pumpPrivacy(
    WidgetTester tester, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) {
    return pumpApp(
      tester,
      BlocProvider<OnboardingCubit>.value(
        value: cubit,
        child: const PrivacyScreen(),
      ),
      locale: locale,
      textScaler: textScaler,
    );
  }

  group('PrivacyScreen', () {
    testWidgets('states all four privacy promises', (tester) async {
      await pumpPrivacy(tester);

      expect(find.text(ar.privacyTitle), findsOneWidget);
      expect(find.text(ar.privacyPointExtractText), findsOneWidget);
      expect(find.text(ar.privacyPointTextOnly), findsOneWidget);
      expect(find.text(ar.privacyPointImageOptIn), findsOneWidget);
      expect(find.text(ar.privacyPointDeleteAnytime), findsOneWidget);
      expect(find.text(ar.privacyAgree), findsOneWidget);
    });

    testWidgets('marks every promise with a tick, under a shield', (
      tester,
    ) async {
      await pumpPrivacy(tester);

      final glyphs = tester
          .widgetList<StrokeIcon>(find.byType(StrokeIcon))
          .map((icon) => icon.glyph)
          .toList();

      expect(glyphs.first, StrokeGlyph.shieldCheck);
      expect(
        glyphs.where((g) => g == StrokeGlyph.check).length,
        4,
        reason: 'one tick per promise',
      );
    });

    testWidgets('agreeing completes onboarding and persists the flag', (
      tester,
    ) async {
      await pumpPrivacy(tester);
      await cubit.load();
      expect(cubit.state, const OnboardingRequired());

      await tester.tap(find.text(ar.privacyAgree));
      await tester.pumpAndSettle();

      expect(cubit.state, const OnboardingCompleted());
      expect(repository.seen, isTrue);
    });

    testWidgets('renders in English, left-to-right', (tester) async {
      await pumpPrivacy(tester, locale: AppLocalizations.english);

      expect(find.text(en.privacyTitle), findsOneWidget);
      expect(find.text(en.privacyPointTextOnly), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(PrimaryCta))),
        TextDirection.ltr,
      );
    });

    testWidgets('lays out right-to-left in Arabic', (tester) async {
      await pumpPrivacy(tester);

      expect(
        Directionality.of(tester.element(find.byType(PrimaryCta))),
        TextDirection.rtl,
      );
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPrivacy(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
      // The consent action must stay reachable however long the copy grows.
      expect(find.text(ar.privacyAgree), findsOneWidget);
    });

    testWidgets('the promises scroll on a short screen', (tester) async {
      tester.view.physicalSize = const Size(390, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpPrivacy(tester);

      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(ar.privacyAgree), findsOneWidget);
    });
  });
}
