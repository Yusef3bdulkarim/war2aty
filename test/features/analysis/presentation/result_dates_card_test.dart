import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_date.dart';
import 'package:war2aty/features/analysis/domain/entities/confidence_band.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_dates_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/value_caveat.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

AnalysisDate _date({
  String label = 'آخر موعد للسداد',
  DateTime? on,
  AnalysisTime? time,
  DateRole role = DateRole.deadline,
  bool isReminderWorthy = true,
  ConfidenceBand confidence = ConfidenceBand.high,
}) => AnalysisDate(
  label: label,
  date: on ?? DateTime(2026, 8, 25),
  time: time,
  role: role,
  isReminderWorthy: isReminderWorthy,
  confidence: confidence,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<AnalysisDate> dates, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultDatesCard(dates: dates)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultDatesCard', () {
    testWidgets('heads the block and writes the date out in full', (
      tester,
    ) async {
      await pumpCard(tester, [_date()]);

      expect(find.text(_strings.resultDatesTitle), findsOneWidget);
      expect(find.text('25 أغسطس 2026'), findsOneWidget);
    });

    testWidgets('says what each date is for', (tester) async {
      await pumpCard(tester, [
        _date(),
        _date(
          label: 'تاريخ إصدار الفاتورة',
          on: DateTime(2026, 8, 10),
          role: DateRole.issued,
          isReminderWorthy: false,
        ),
      ]);

      expect(find.text('آخر موعد للسداد'), findsOneWidget);
      expect(find.text('تاريخ إصدار الفاتورة'), findsOneWidget);
    });

    testWidgets('keeps the order the analysis reported', (tester) async {
      await pumpCard(tester, [
        _date(label: 'الأولى'),
        _date(label: 'التانية', on: DateTime(2026, 8, 10)),
      ]);

      final first = tester.getTopLeft(find.text('الأولى'));
      final second = tester.getTopLeft(find.text('التانية'));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('shows the time the paper gives', (tester) async {
      await pumpCard(tester, [
        _date(time: const AnalysisTime(hour: 10, minute: 0)),
      ]);

      expect(find.text('10:00 ${_strings.timeAm}'), findsOneWidget);
      expect(find.text(_strings.resultDateNoTime), findsNothing);
    });

    testWidgets('says so rather than inventing a missing time', (tester) async {
      await pumpCard(tester, [_date()]);

      expect(find.text(_strings.resultDateNoTime), findsOneWidget);
    });

    testWidgets('qualifies a date the analysis is unsure of', (tester) async {
      await pumpCard(tester, [_date(confidence: ConfidenceBand.medium)]);

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('lets a certain date stand on its own', (tester) async {
      await pumpCard(tester, [_date()]);

      expect(find.byType(ValueCaveat), findsNothing);
    });

    testWidgets('the day tile is not read out twice', (tester) async {
      await pumpCard(tester, [_date()]);

      // The tile repeats the day and month already spelled out beside it.
      expect(find.text('25'), findsOneWidget);
      expect(find.text('أغسطس'), findsOneWidget);
      expect(find.bySemanticsLabel('25'), findsNothing);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpCard(tester, [
        _date(
          label: 'آخر موعد لتقديم المستندات لمكتب السجل المدني',
          confidence: ConfidenceBand.low,
        ),
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, [_date()], locale: AppLocalizations.english);

      const english = EnStrings();
      expect(find.text(english.resultDatesTitle), findsOneWidget);
      expect(find.text('25 August 2026'), findsOneWidget);
      expect(find.text(english.resultDateNoTime), findsOneWidget);
    });
  });
}
