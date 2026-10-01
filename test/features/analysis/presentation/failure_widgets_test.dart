import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/extracted_text_entry_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/failure_note_chip.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/supported_documents_section.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
}) => pumpApp(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: child,
    ),
  ),
  locale: locale,
  textScaler: textScaler,
);

void main() {
  group('FailureNoteChip', () {
    testWidgets('says it with a check and words, in the success ink', (
      tester,
    ) async {
      await _pump(
        tester,
        FailureNoteChip(text: _strings.analysisAttemptNotCounted),
      );

      expect(find.text(_strings.analysisAttemptNotCounted), findsOneWidget);
      final icon = tester.widget<StrokeIcon>(find.byType(StrokeIcon));
      expect(icon.glyph, StrokeGlyph.check);
      expect(icon.color, AppColors.light.successInk);
    });
  });

  group('ExtractedTextEntryCard', () {
    testWidgets('names the text and opens it on tap', (tester) async {
      var taps = 0;
      await _pump(tester, ExtractedTextEntryCard(onTap: () => taps++));

      expect(find.text(_strings.resultShowExtractedText), findsOneWidget);
      expect(
        find.text(_strings.analysisExtractedTextCardSubtitle),
        findsOneWidget,
      );

      await tester.tap(find.byType(ExtractedTextEntryCard));
      expect(taps, 1);
    });

    testWidgets('is one button to a screen reader', (tester) async {
      await _pump(tester, ExtractedTextEntryCard(onTap: () {}));

      expect(
        tester.getSemantics(find.byType(InkWell)),
        isSemantics(isButton: true, hasTapAction: true),
      );
    });

    testWidgets('points its chevron onward: left in RTL, right in LTR', (
      tester,
    ) async {
      Matrix4 flip() => tester
          .widget<Transform>(
            find.byWidgetPredicate(
              (w) =>
                  w is Transform &&
                  w.child is StrokeIcon &&
                  (w.child! as StrokeIcon).glyph == StrokeGlyph.chevronForward,
            ),
          )
          .transform;

      await _pump(tester, ExtractedTextEntryCard(onTap: () {}));
      expect(flip().storage[0], 1);

      await _pump(
        tester,
        ExtractedTextEntryCard(onTap: () {}),
        locale: AppLocalizations.english,
      );
      expect(flip().storage[0], -1);
    });
  });

  group('SupportedDocumentsSection', () {
    testWidgets('lists the five kinds with their examples', (tester) async {
      await _pump(tester, const SupportedDocumentsSection());

      expect(
        find.text(_strings.analysisSupportedDocumentsTitle),
        findsOneWidget,
      );
      for (final text in [
        _strings.analysisSupportedInvoices,
        _strings.analysisSupportedInvoicesExamples,
        _strings.analysisSupportedAppointments,
        _strings.analysisSupportedAppointmentsExamples,
        _strings.analysisSupportedGovernment,
        _strings.analysisSupportedGovernmentExamples,
        _strings.analysisSupportedEducation,
        _strings.analysisSupportedEducationExamples,
        _strings.analysisSupportedOther,
        _strings.analysisSupportedOtherExamples,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('lays the four in pairs and «أوراق تانية» across the width', (
      tester,
    ) async {
      await _pump(tester, const SupportedDocumentsSection());

      final invoices = tester.getRect(
        find.text(_strings.analysisSupportedInvoices),
      );
      final appointments = tester.getRect(
        find.text(_strings.analysisSupportedAppointments),
      );
      final government = tester.getRect(
        find.text(_strings.analysisSupportedGovernment),
      );
      final other = tester.getRect(find.text(_strings.analysisSupportedOther));

      // Same row, invoices at the start (the right, in RTL).
      expect(invoices.top, moreOrLessEquals(appointments.top));
      expect(invoices.left, greaterThan(appointments.left));
      expect(government.top, greaterThan(invoices.bottom));
      expect(other.top, greaterThan(government.bottom));
    });

    testWidgets('reads each kind with its examples as one stop', (
      tester,
    ) async {
      await _pump(tester, const SupportedDocumentsSection());

      expect(
        find.bySemanticsLabel(
          RegExp(
            '${_strings.analysisSupportedInvoices}.*'
            '${_strings.analysisSupportedInvoicesExamples}',
            dotAll: true,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('fits a small phone at 2.0× text, in both languages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await _pump(
          tester,
          const SupportedDocumentsSection(),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });
  });
}
