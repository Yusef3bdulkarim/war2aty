import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/money/document_amount_label.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_amount.dart';
import 'package:war2aty/features/analysis/domain/entities/confidence_band.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_amounts_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/value_caveat.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

AnalysisAmount _amount({
  String label = 'المبلغ المطلوب',
  double value = 750,
  String currency = 'EGP',
  ConfidenceBand confidence = ConfidenceBand.high,
}) => AnalysisAmount(
  label: label,
  value: value,
  currency: currency,
  confidence: confidence,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<AnalysisAmount> amounts, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultAmountsCard(amounts: amounts)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultAmountsCard', () {
    testWidgets('heads the block and shows each figure with its currency', (
      tester,
    ) async {
      await pumpCard(tester, [_amount()]);

      expect(find.text(_strings.resultAmountsTitle), findsOneWidget);
      expect(find.text('المبلغ المطلوب'), findsOneWidget);
      expect(find.text('750 جنيه'), findsOneWidget);
    });

    testWidgets('qualifies a figure the analysis is unsure of', (tester) async {
      await pumpCard(tester, [_amount(confidence: ConfidenceBand.medium)]);

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('lets a certain figure stand on its own', (tester) async {
      await pumpCard(tester, [_amount()]);

      expect(find.byType(ValueCaveat), findsNothing);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpCard(tester, [
        _amount(
          label: 'إجمالي المبلغ المطلوب سداده عن شهر أغسطس',
          value: 1250.75,
          confidence: ConfidenceBand.low,
        ),
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, [_amount()], locale: AppLocalizations.english);

      expect(find.text(const EnStrings().resultAmountsTitle), findsOneWidget);
      expect(find.text('750 EGP'), findsOneWidget);
    });
  });

  group('formatDocumentAmount', () {
    test('writes a whole figure without a decimal part', () {
      expect(formatDocumentAmount(_strings, 750, 'EGP'), '750 جنيه');
    });

    test('keeps both digits when there are piastres', () {
      // `250.5` must never read as "250 pounds 5".
      expect(formatDocumentAmount(_strings, 250.5, 'EGP'), '250.50 جنيه');
    });

    test('names the currencies the app expects to meet', () {
      expect(formatDocumentAmount(_strings, 20, 'USD'), '20 دولار');
      expect(formatDocumentAmount(_strings, 20, 'egp'), '20 جنيه');
    });

    test('shows an unknown code as it arrived rather than dropping it', () {
      expect(formatDocumentAmount(_strings, 20, 'XYZ'), '20 XYZ');
    });
  });
}
