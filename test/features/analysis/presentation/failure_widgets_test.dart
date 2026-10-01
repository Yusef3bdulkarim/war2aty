import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/analysis_steps_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/consent_value_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/extracted_text_entry_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/failure_note_chip.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/failure_tips_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/limit_reset_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/privacy_text_note.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/supported_documents_section.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

/// The usage pill's dots, one per analysis.
final _dots = find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('usage-dot-'),
);

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

  group('AnalysisStepsCard', () {
    List<StrokeGlyph> glyphs(WidgetTester tester) => tester
        .widgetList<StrokeIcon>(find.byType(StrokeIcon))
        .map((icon) => icon.glyph)
        .toList();

    testWidgets('two done steps, then the explanation waiting', (tester) async {
      await _pump(
        tester,
        const AnalysisStepsCard(explanation: ExplanationStep.waiting),
      );

      expect(glyphs(tester), [
        StrokeGlyph.check,
        StrokeGlyph.check,
        StrokeGlyph.clock,
      ]);
      expect(find.text(_strings.analysisStepDone), findsNWidgets(2));
      expect(
        find.text(_strings.analysisStepWaitingForInternet),
        findsOneWidget,
      );
    });

    testWidgets('or failed, with a warning', (tester) async {
      await _pump(
        tester,
        const AnalysisStepsCard(explanation: ExplanationStep.failed),
      );

      expect(glyphs(tester).last, StrokeGlyph.warningTriangle);
      expect(find.text(_strings.analysisStepNotFinished), findsOneWidget);
    });

    testWidgets('runs right to left: the photo first', (tester) async {
      await _pump(
        tester,
        const AnalysisStepsCard(explanation: ExplanationStep.waiting),
      );

      final photo = tester.getCenter(find.text(_strings.analysisStepPhoto));
      final reading = tester.getCenter(find.text(_strings.analysisStepReading));
      final explanation = tester.getCenter(
        find.text(_strings.analysisStepExplanation),
      );
      expect(photo.dx, greaterThan(reading.dx));
      expect(reading.dx, greaterThan(explanation.dx));
    });

    testWidgets('is one sentence to a screen reader', (tester) async {
      await _pump(
        tester,
        const AnalysisStepsCard(explanation: ExplanationStep.failed),
      );

      expect(
        find.bySemanticsLabel(
          _strings.analysisStepsSemantics(_strings.analysisStepNotFinished),
        ),
        findsOneWidget,
      );
      // The step words themselves are not read a second time: the sentence
      // is the only node that mentions the photo.
      expect(
        find.bySemanticsLabel(RegExp(_strings.analysisStepPhoto)),
        findsOneWidget,
      );
    });

    testWidgets('fits a small phone at 2.0× text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await _pump(
          tester,
          const AnalysisStepsCard(explanation: ExplanationStep.waiting),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });
  });

  group('FailureTipsCard', () {
    testWidgets('heads its tips and draws each with its icon', (tester) async {
      await _pump(
        tester,
        FailureTipsCard(
          title: _strings.analysisNoInternetTipsTitle,
          tips: [
            FailureTip(
              glyph: StrokeGlyph.wifi,
              text: _strings.analysisNoInternetTipWifi,
            ),
            FailureTip(
              glyph: StrokeGlyph.lightbulb,
              text: _strings.analysisLimitTipTomorrow,
              tone: FailureTipTone.amber,
            ),
          ],
        ),
      );

      expect(
        tester.getSemantics(find.text(_strings.analysisNoInternetTipsTitle)),
        isSemantics(isHeader: true),
      );
      expect(find.text(_strings.analysisNoInternetTipWifi), findsOneWidget);
      final icons = tester.widgetList<StrokeIcon>(find.byType(StrokeIcon));
      expect(icons.map((i) => i.glyph), [
        StrokeGlyph.wifi,
        StrokeGlyph.lightbulb,
      ]);
      expect(icons.map((i) => i.color), [
        AppColors.light.brandPrimary,
        AppColors.light.warningInk,
      ]);
    });
  });

  group('LimitResetCard', () {
    final resetAt = DateTime.utc(2026, 10, 1, 22);
    late DateTime now;

    Future<void> pumpCard(
      WidgetTester tester, {
      required Duration left,
      int? dailyLimit,
      TextScaler? textScaler,
    }) {
      now = resetAt.subtract(left);
      return _pump(
        tester,
        LimitResetCard(
          resetAt: resetAt,
          dailyLimit: dailyLimit,
          now: () => now,
        ),
        textScaler: textScaler,
      );
    }

    /// Moves the injected clock and the test's fake timers together.
    Future<void> advance(WidgetTester tester, Duration by) async {
      now = now.add(by);
      await tester.pump(by);
    }

    testWidgets('says how long until the analyses renew', (tester) async {
      await pumpCard(tester, left: const Duration(hours: 5, minutes: 12));

      expect(find.text(_strings.analysisLimitResetsInLabel), findsOneWidget);
      expect(find.text('5 ساعات و 12 دقيقة'), findsOneWidget);
      expect(find.text(_strings.analysisLimitResetTime), findsOneWidget);
    });

    testWidgets('rounds a part-minute up, never down to zero', (tester) async {
      await pumpCard(
        tester,
        left: const Duration(hours: 5, minutes: 11, seconds: 30),
      );
      expect(find.text('5 ساعات و 12 دقيقة'), findsOneWidget);

      await pumpCard(tester, left: const Duration(seconds: 20));
      expect(find.text('دقيقة'), findsOneWidget);
    });

    testWidgets('changes the minute exactly when it turns', (tester) async {
      await pumpCard(tester, left: const Duration(minutes: 2, seconds: 30));
      expect(find.text('3 دقايق'), findsOneWidget);

      await advance(tester, const Duration(seconds: 29));
      expect(find.text('3 دقايق'), findsOneWidget);

      await advance(tester, const Duration(seconds: 1));
      expect(find.text('دقيقتين'), findsOneWidget);

      await advance(tester, const Duration(minutes: 1));
      expect(find.text('دقيقة'), findsOneWidget);
    });

    testWidgets('says the analyses renewed once the time is up', (
      tester,
    ) async {
      await pumpCard(tester, left: const Duration(seconds: 30));
      expect(find.text('دقيقة'), findsOneWidget);

      await advance(tester, const Duration(seconds: 30));
      expect(find.text(_strings.analysisLimitRenewed), findsOneWidget);
      expect(find.text(_strings.analysisLimitResetsInLabel), findsNothing);
    });

    testWidgets('starts renewed when the reset has passed', (tester) async {
      await pumpCard(tester, left: const Duration(minutes: -5));

      expect(find.text(_strings.analysisLimitRenewed), findsOneWidget);
    });

    testWidgets('names the limit with one dot per analysis', (tester) async {
      await pumpCard(tester, left: const Duration(hours: 1), dailyLimit: 3);

      expect(find.text(_strings.analysisLimitUsedOf(3)), findsOneWidget);
      expect(_dots, findsNWidgets(3));
    });

    testWidgets('drops the dots for a large limit, keeps the words', (
      tester,
    ) async {
      await pumpCard(tester, left: const Duration(hours: 1), dailyLimit: 12);

      expect(find.text(_strings.analysisLimitUsedOf(12)), findsOneWidget);
      expect(_dots, findsNothing);
    });

    testWidgets('leaves the pill out when the limit is unknown', (
      tester,
    ) async {
      await pumpCard(tester, left: const Duration(hours: 1));

      expect(find.textContaining('استخدمت'), findsNothing);
      expect(_dots, findsNothing);
    });

    testWidgets('stops its timer when removed', (tester) async {
      await pumpCard(tester, left: const Duration(hours: 1));

      await tester.pumpWidget(const SizedBox());
      // A timer left running would fail the test as pending.
      await tester.pump(const Duration(hours: 2));
    });

    testWidgets('fits a small phone at 2.0× text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpCard(
        tester,
        left: const Duration(hours: 10, minutes: 59),
        dailyLimit: 10,
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ConsentValueCard', () {
    testWidgets('heads the four things the analysis would say', (tester) async {
      await _pump(tester, const ConsentValueCard());

      expect(
        tester.getSemantics(find.text(_strings.analysisConsentValueTitle)),
        isSemantics(isHeader: true),
      );
      for (final label in [
        _strings.analysisConsentValueType,
        _strings.analysisConsentValueKeyPoints,
        _strings.analysisConsentValueRequired,
        _strings.analysisConsentValueDates,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        tester
            .widgetList<StrokeIcon>(find.byType(StrokeIcon))
            .map((i) => i.glyph),
        [
          StrokeGlyph.documentSteps,
          StrokeGlyph.sparkle,
          StrokeGlyph.checkSquare,
          StrokeGlyph.clock,
        ],
      );
    });

    testWidgets('lays the tiles in two pairs', (tester) async {
      await _pump(tester, const ConsentValueCard());

      final type = tester.getRect(find.text(_strings.analysisConsentValueType));
      final keyPoints = tester.getRect(
        find.text(_strings.analysisConsentValueKeyPoints),
      );
      final required = tester.getRect(
        find.text(_strings.analysisConsentValueRequired),
      );
      expect(type.top, moreOrLessEquals(keyPoints.top));
      expect(type.left, greaterThan(keyPoints.left));
      expect(required.top, greaterThan(type.bottom));
    });

    testWidgets('fits a small phone at 2.0× text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await _pump(
          tester,
          const ConsentValueCard(),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });
  });

  group('PrivacyTextNote', () {
    testWidgets('says the approved wording, word for word', (tester) async {
      await _pump(tester, const PrivacyTextNote());

      // CLAUDE.md §7, the text's approved sentence.
      expect(
        find.text(
          'بنبعت نص ورقتك مشفَّر لخدمة تحليل علشان نفهمه، ومانحفظش النص عندنا.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).glyph,
        StrokeGlyph.shieldCheck,
      );
    });
  });
}
