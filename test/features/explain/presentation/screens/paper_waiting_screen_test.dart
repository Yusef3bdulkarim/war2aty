import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/explain/presentation/screens/paper_waiting_screen.dart';

import '../../../../support/pump_app.dart';
import '../../../../support/ui_audit.dart';

const _ar = ArStrings();
const _en = EnStrings();

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
  bool reducedMotion = false,
}) async {
  const base = PaperWaitingScreen();
  final screen = reducedMotion
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: base,
          ),
        )
      : base;
  await pumpApp(
    tester,
    screen,
    locale: locale,
    textScaler: textScaler,
    settle: false,
  );
  await tester.pump();
}

bool _anyAnimating(WidgetTester tester) => tester
    .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
    .map((builder) => builder.animation)
    .whereType<AnimationController>()
    .any((controller) => controller.isAnimating);

void main() {
  auditScreenLayout(
    'PaperWaitingScreen',
    (tester, locale, scaler) =>
        _pump(tester, locale: locale, textScaler: scaler),
  );

  group('PaperWaitingScreen', () {
    testWidgets('shows the waiting sentence in Arabic', (tester) async {
      await _pump(tester);

      expect(find.text(_ar.paperWaitingSentence), findsOneWidget);
    });

    testWidgets('shows the waiting sentence in English', (tester) async {
      await _pump(tester, locale: AppLocalizations.english);

      expect(find.text(_en.paperWaitingSentence), findsOneWidget);
    });

    testWidgets('lays out right-to-left by default', (tester) async {
      await _pump(tester);

      expect(
        Directionality.of(tester.element(find.text(_ar.paperWaitingSentence))),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pump(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('the scan line, the wave bars and the dots are animating', (
      tester,
    ) async {
      await _pump(tester);

      expect(_anyAnimating(tester), isTrue);
    });

    testWidgets('nothing animates under reduced motion', (tester) async {
      await _pump(tester, reducedMotion: true);

      expect(_anyAnimating(tester), isFalse);
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });
}
