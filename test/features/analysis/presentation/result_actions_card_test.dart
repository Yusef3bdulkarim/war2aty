import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/domain/entities/required_action.dart';
import 'package:war2aty/features/analysis/presentation/widgets/caveat_badge.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_actions_card.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

const _explicit = RequiredAction(
  description: 'سدد 750 جنيه قبل يوم 25 أغسطس 2026.',
  basis: ActionBasis.explicit,
  priority: ActionPriority.high,
);

const _inferred = RequiredAction(
  description: 'يبدو إن المطلوب هو تجديد الاشتراك.',
  basis: ActionBasis.inferred,
  priority: ActionPriority.normal,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<RequiredAction> actions, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultActionsCard(actions: actions)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultActionsCard', () {
    testWidgets('names the section and spells out the action', (tester) async {
      await pumpCard(tester, const [_explicit]);

      expect(find.text(_strings.resultActionRequiredTitle), findsOneWidget);
      expect(find.text(_explicit.description), findsOneWidget);
    });

    testWidgets('leaves an action the paper states plainly unqualified', (
      tester,
    ) async {
      await pumpCard(tester, const [_explicit]);

      expect(find.byType(CaveatBadge), findsNothing);
    });

    testWidgets('marks an action the analysis worked out for itself', (
      tester,
    ) async {
      await pumpCard(tester, const [_inferred]);

      expect(find.text(_strings.resultActionInferred), findsOneWidget);
    });

    testWidgets('labels each action on its own basis', (tester) async {
      await pumpCard(tester, const [_explicit, _inferred]);

      expect(find.text(_explicit.description), findsOneWidget);
      expect(find.text(_inferred.description), findsOneWidget);
      // Only the inferred one is qualified — the badge belongs to the line it
      // is about, not to the card (UX rule §5.9).
      expect(find.byType(CaveatBadge), findsOneWidget);
    });

    testWidgets('keeps the order the analysis reported', (tester) async {
      await pumpCard(tester, const [_inferred, _explicit]);

      final first = tester.getTopLeft(find.text(_inferred.description));
      final second = tester.getTopLeft(find.text(_explicit.description));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('the section name is a heading for assistive technology', (
      tester,
    ) async {
      await pumpCard(tester, const [_explicit]);

      expect(
        tester.getSemantics(find.text(_strings.resultActionRequiredTitle)),
        isSemantics(isHeader: true),
      );
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpCard(tester, const [
        _explicit,
        _inferred,
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, const [
        _inferred,
      ], locale: AppLocalizations.english);

      const english = EnStrings();
      expect(find.text(english.resultActionRequiredTitle), findsOneWidget);
      expect(find.text(english.resultActionInferred), findsOneWidget);
    });
  });
}
