import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/domain/entities/confidence_band.dart';
import 'package:war2aty/features/analysis/domain/entities/key_information.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_key_information_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/value_caveat.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

KeyInformation _item({
  String label = 'رقم المشترك',
  String value = '624512',
  ConfidenceBand confidence = ConfidenceBand.high,
  InfoSource source = InfoSource.extracted,
}) => KeyInformation(
  label: label,
  value: value,
  confidence: confidence,
  source: source,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<KeyInformation> items, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultKeyInformationCard(items: items)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultKeyInformationCard', () {
    testWidgets('heads the list and shows each label with its value', (
      tester,
    ) async {
      await pumpCard(tester, [
        _item(),
        _item(label: 'الجهة', value: 'شركة الكهرباء'),
      ]);

      expect(find.text(_strings.resultKeyInformationTitle), findsOneWidget);
      expect(find.text('رقم المشترك'), findsOneWidget);
      expect(find.text('624512'), findsOneWidget);
      expect(find.text('الجهة'), findsOneWidget);
      expect(find.text('شركة الكهرباء'), findsOneWidget);
    });

    testWidgets('lets a value the analysis is sure of stand on its own', (
      tester,
    ) async {
      await pumpCard(tester, [_item()]);

      expect(find.byType(ValueCaveat), findsNothing);
    });

    testWidgets('asks the user to check a medium-confidence value', (
      tester,
    ) async {
      await pumpCard(tester, [_item(confidence: ConfidenceBand.medium)]);

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('marks a low-confidence value as an uncertain reading', (
      tester,
    ) async {
      await pumpCard(tester, [_item(confidence: ConfidenceBand.low)]);

      expect(find.text(_strings.confidenceUncertain), findsOneWidget);
    });

    testWidgets('marks a value the paper never stated', (tester) async {
      await pumpCard(tester, [_item(source: InfoSource.inferred)]);

      expect(find.text(_strings.resultActionInferred), findsOneWidget);
    });

    testWidgets('says both when a value is inferred and uncertain', (
      tester,
    ) async {
      await pumpCard(tester, [
        _item(confidence: ConfidenceBand.low, source: InfoSource.inferred),
      ]);

      expect(find.byType(ValueCaveat), findsNWidgets(2));
      expect(find.text(_strings.confidenceUncertain), findsOneWidget);
      expect(find.text(_strings.resultActionInferred), findsOneWidget);
    });

    testWidgets('qualifies only the row it is about', (tester) async {
      await pumpCard(tester, [
        _item(),
        _item(
          label: 'المبلغ المطلوب',
          value: '750',
          confidence: ConfidenceBand.medium,
        ),
      ]);

      // Per-value, never per-document (UX rule §5.9).
      expect(find.byType(ValueCaveat), findsOneWidget);
    });

    testWidgets('copies one value to the clipboard', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpCard(tester, [_item()]);
      await tester.tap(
        find.bySemanticsLabel(_strings.resultCopyValueLabel('رقم المشترك')),
      );
      await tester.pumpAndSettle();

      expect(copied, ['624512']);
      expect(find.text(_strings.ocrTextCopied), findsOneWidget);
    });

    testWidgets('lays out a long label and value under Large Text', (
      tester,
    ) async {
      await pumpCard(tester, [
        _item(
          label: 'رقم المعاملة لدى مكتب السجل المدني',
          value: '2026/8841 — فرع الجيزة',
          confidence: ConfidenceBand.low,
          source: InfoSource.inferred,
        ),
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, [_item()], locale: AppLocalizations.english);

      expect(
        find.text(const EnStrings().resultKeyInformationTitle),
        findsOneWidget,
      );
    });
  });
}
