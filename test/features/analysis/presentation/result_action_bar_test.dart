import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/date_selection_sheet.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_action_bar.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

AnalysisDate _date({
  String label = 'آخر موعد للسداد',
  DateTime? on,
  DateRole role = DateRole.deadline,
}) => AnalysisDate(
  label: label,
  date: on ?? DateTime(2026, 8, 25),
  role: role,
  isReminderWorthy: true,
  confidence: ConfidenceBand.high,
);

final _deadline = _date();
final _issued = _date(
  label: 'تاريخ إصدار الفاتورة',
  on: DateTime(2026, 8, 10),
  role: DateRole.issued,
);

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    List<AnalysisDate> dates = const [],
    VoidCallback? onListen,
    ValueChanged<AnalysisDate>? onCreateReminder,
    VoidCallback? onSave,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ResultActionBar(
          dates: dates,
          onListen: onListen,
          onCreateReminder: onCreateReminder,
          onSave: onSave,
        ),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultActionBar', () {
    testWidgets('offers the three basic actions when all three can run', (
      tester,
    ) async {
      await pumpBar(
        tester,
        dates: [_deadline],
        onListen: () {},
        onCreateReminder: (_) {},
        onSave: () {},
      );

      expect(find.text(_strings.resultListen), findsOneWidget);
      expect(find.text(_strings.resultCreateReminder), findsOneWidget);
      expect(find.text(_strings.resultSavePaper), findsOneWidget);
    });

    testWidgets('leaves out a button with nowhere to go', (tester) async {
      await pumpBar(tester, dates: [_deadline], onSave: () {});

      // Better a shorter bar than controls that acknowledge a tap and do
      // nothing.
      expect(find.text(_strings.resultSavePaper), findsOneWidget);
      expect(find.text(_strings.resultListen), findsNothing);
      expect(find.text(_strings.resultCreateReminder), findsNothing);
    });

    testWidgets('disappears entirely when none of the three can run', (
      tester,
    ) async {
      await pumpBar(tester, dates: [_deadline]);

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('hides the reminder when the paper carries no date', (
      tester,
    ) async {
      await pumpBar(tester, onCreateReminder: (_) {}, onSave: () {});

      // There is nothing to be reminded about.
      expect(find.text(_strings.resultCreateReminder), findsNothing);
      expect(find.text(_strings.resultSavePaper), findsOneWidget);
    });

    testWidgets('reads the paper aloud', (tester) async {
      var listened = 0;
      await pumpBar(tester, onListen: () => listened++);

      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();

      expect(listened, 1);
    });

    testWidgets('keeps the paper', (tester) async {
      var saved = 0;
      await pumpBar(tester, onSave: () => saved++);

      await tester.tap(find.text(_strings.resultSavePaper));
      await tester.pumpAndSettle();

      expect(saved, 1);
    });

    testWidgets('starts a reminder straight away for a single date', (
      tester,
    ) async {
      final chosen = <AnalysisDate>[];
      await pumpBar(tester, dates: [_deadline], onCreateReminder: chosen.add);

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();

      expect(chosen, [_deadline]);
      expect(find.byType(DateSelectionSheet), findsNothing);
    });

    testWidgets('asks which date when the paper has several', (tester) async {
      final chosen = <AnalysisDate>[];
      await pumpBar(
        tester,
        dates: [_deadline, _issued],
        onCreateReminder: chosen.add,
      );

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();

      expect(find.byType(DateSelectionSheet), findsOneWidget);
      expect(chosen, isEmpty);

      await tester.tap(
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
      await pumpBar(
        tester,
        dates: [_deadline, _issued],
        onCreateReminder: chosen.add,
      );

      await tester.tap(find.text(_strings.resultCreateReminder));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpBar(
        tester,
        dates: [_deadline],
        onListen: () {},
        onCreateReminder: (_) {},
        onSave: () {},
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpBar(
        tester,
        dates: [_deadline],
        onListen: () {},
        onCreateReminder: (_) {},
        onSave: () {},
        locale: AppLocalizations.english,
      );

      const english = EnStrings();
      expect(find.text(english.resultListen), findsOneWidget);
      expect(find.text(english.resultCreateReminder), findsOneWidget);
      expect(find.text(english.resultSavePaper), findsOneWidget);
    });
  });
}
