import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/date_selection_sheet.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_dates_card.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

AnalysisDate _date({
  String label = 'آخر موعد للسداد',
  DateTime? on,
  DateRole role = DateRole.deadline,
  bool isReminderWorthy = true,
}) => AnalysisDate(
  label: label,
  date: on ?? DateTime(2026, 8, 25),
  role: role,
  isReminderWorthy: isReminderWorthy,
  confidence: ConfidenceBand.high,
);

final _deadline = _date();
final _issued = _date(
  label: 'تاريخ إصدار الفاتورة',
  on: DateTime(2026, 8, 10),
  role: DateRole.issued,
  isReminderWorthy: false,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<AnalysisDate> dates, {
    ValueChanged<AnalysisDate>? onCreateReminder,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(
      body: ResultDatesCard(dates: dates, onCreateReminder: onCreateReminder),
    ),
    locale: locale,
    textScaler: textScaler,
  );

  group('the reminder entry point', () {
    testWidgets('is left out while there is nowhere for it to go', (
      tester,
    ) async {
      await pumpCard(tester, [_deadline]);

      expect(find.text(_strings.resultCreateReminder), findsNothing);
    });

    testWidgets('goes straight through when the paper has one date', (
      tester,
    ) async {
      final chosen = <AnalysisDate>[];
      await pumpCard(tester, [_deadline], onCreateReminder: chosen.add);

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();

      expect(chosen, [_deadline]);
      // Nothing to ask about, so nothing is asked.
      expect(find.text(_strings.resultPickDateTitle), findsNothing);
    });

    testWidgets('asks which date when the paper has several', (tester) async {
      final chosen = <AnalysisDate>[];
      await pumpCard(tester, [
        _deadline,
        _issued,
      ], onCreateReminder: chosen.add);

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();

      expect(find.text(_strings.resultPickDateTitle), findsOneWidget);
      expect(find.text(_strings.resultPickDateMessage), findsOneWidget);
      // Nothing chosen for the user in the meantime (UX rule §5.5).
      expect(chosen, isEmpty);
    });

    testWidgets('starts the reminder for the date the user picked', (
      tester,
    ) async {
      final chosen = <AnalysisDate>[];
      await pumpCard(tester, [
        _deadline,
        _issued,
      ], onCreateReminder: chosen.add);

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();
      await tester.tap(
        // Scoped to the sheet — the card behind it lists the same date.
        find.descendant(
          of: find.byType(DateSelectionSheet),
          matching: find.text(_issued.label),
        ),
      );
      await tester.pumpAndSettle();

      expect(chosen, [_issued]);
    });

    testWidgets('schedules nothing when the sheet is dismissed', (
      tester,
    ) async {
      final chosen = <AnalysisDate>[];
      await pumpCard(tester, [
        _deadline,
        _issued,
      ], onCreateReminder: chosen.add);

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();
      // Tapping the scrim dismisses the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
      expect(find.text(_strings.resultPickDateTitle), findsNothing);
    });
  });

  group('DateSelectionSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      List<AnalysisDate> dates, {
      Locale locale = AppLocalizations.arabic,
      TextScaler? textScaler,
    }) => pumpApp(
      tester,
      Scaffold(body: DateSelectionSheet(dates: dates)),
      locale: locale,
      textScaler: textScaler,
    );

    testWidgets('offers every date on the paper, not only the suggested one', (
      tester,
    ) async {
      await pumpSheet(tester, [_deadline, _issued]);

      expect(find.text(_deadline.label), findsOneWidget);
      expect(find.text(_issued.label), findsOneWidget);
      expect(find.text('25 أغسطس 2026'), findsOneWidget);
      expect(find.text('10 أغسطس 2026'), findsOneWidget);
    });

    testWidgets('says which dates are worth remembering and which are not', (
      tester,
    ) async {
      await pumpSheet(tester, [_deadline, _issued]);

      expect(find.text(_strings.resultDateReminderWorthy), findsOneWidget);
      expect(find.text(_strings.resultDateDisplayOnly), findsOneWidget);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpSheet(tester, [
        _date(label: 'آخر موعد لتقديم المستندات لمكتب السجل المدني'),
        _issued,
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpSheet(tester, [
        _deadline,
        _issued,
      ], locale: AppLocalizations.english);

      const english = EnStrings();
      expect(find.text(english.resultPickDateTitle), findsOneWidget);
      expect(find.text(english.resultDateReminderWorthy), findsOneWidget);
      expect(find.text(english.resultDateDisplayOnly), findsOneWidget);
    });
  });
}
