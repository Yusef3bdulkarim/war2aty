import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_warning.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_warnings_card.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

const _medical = AnalysisWarning(
  text: 'التطبيق بيساعدك تفهم المكتوب فقط، ومش بديل عن الطبيب.',
  kind: WarningKind.medical,
);

const _government = AnalysisWarning(
  text: 'راجع الجهة الرسمية قبل تقديم مستندات أو دفع أي رسوم.',
  kind: WarningKind.government,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<AnalysisWarning> warnings, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultWarningsCard(warnings: warnings)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultWarningsCard', () {
    testWidgets('heads the block and shows the disclaimer', (tester) async {
      await pumpCard(tester, const [_medical]);

      expect(find.text(_strings.resultWarningsTitle), findsOneWidget);
      expect(find.text(_medical.text), findsOneWidget);
    });

    testWidgets('shows every disclaimer under one heading', (tester) async {
      await pumpCard(tester, const [_medical, _government]);

      expect(find.text(_strings.resultWarningsTitle), findsOneWidget);
      expect(find.text(_medical.text), findsOneWidget);
      expect(find.text(_government.text), findsOneWidget);
    });

    testWidgets('does not lean on colour alone', (tester) async {
      await pumpCard(tester, const [_medical]);

      // The amber fill is backed by an icon and a heading, so the block still
      // reads as a caution in high contrast or greyscale (CLAUDE.md).
      expect(find.byType(StrokeIcon), findsOneWidget);
      expect(find.text(_strings.resultWarningsTitle), findsOneWidget);
    });

    testWidgets('the heading is a heading for assistive technology', (
      tester,
    ) async {
      await pumpCard(tester, const [_medical]);

      expect(
        tester.getSemantics(find.text(_strings.resultWarningsTitle)),
        isSemantics(isHeader: true),
      );
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpCard(tester, const [
        _medical,
        _government,
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, const [
        _medical,
      ], locale: AppLocalizations.english);

      expect(find.text(const EnStrings().resultWarningsTitle), findsOneWidget);
    });
  });
}
