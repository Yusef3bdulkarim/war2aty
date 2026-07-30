import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/build_analysis_result.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:war2aty/features/analysis/presentation/widgets/analysis_progress_view.dart';
import 'package:war2aty/features/analysis/presentation/widgets/extracted_text_only_view.dart';
import 'package:war2aty/features/analysis/presentation/widgets/partial_result_banner.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_header_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_summary_card.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';

import '../../../support/pump_app.dart';
import '../analysis_fixtures.dart';

const _strings = ArStrings();

const _session = AnalysisSession(id: 'session-1', imagePath: '/tmp/paper.jpg');

const _extraction = ExtractionResult(
  text: NormalizedOcrText(
    originalText: 'فاتورة كهرباء ٢٥٠',
    cleanedText: 'فاتورة كهرباء 250',
  ),
);

final class _FakeRepository implements AnalysisRepository {
  Result<DocumentAnalysis, AppFailure>? answer;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    calls++;
    await gate?.future;
    return answer ?? Ok(invoiceAnalysis());
  }
}

void main() {
  late _FakeRepository repository;
  late AnalysisResultCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = AnalysisResultCubit(
      session: _session,
      extraction: _extraction,
      analyzeDocument: AnalyzeDocument(repository),
      buildResult: const BuildAnalysisResult(),
    );
  });

  tearDown(() => cubit.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onClose,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    bool settle = true,
  }) => pumpApp(
    tester,
    BlocProvider<AnalysisResultCubit>.value(
      value: cubit,
      child: AnalysisResultScreen(onClose: onClose),
    ),
    locale: locale,
    textScaler: textScaler,
    settle: settle,
  );

  group('AnalysisResultScreen', () {
    testWidgets('shows the progress page while the analysis runs', (
      tester,
    ) async {
      repository.gate = Completer<void>();
      unawaited(cubit.analyze());
      await pumpScreen(tester);

      expect(find.byType(AnalysisProgressView), findsOneWidget);
      expect(find.text(_strings.analysisRunningTitle), findsOneWidget);
      // No way out mid-analysis: the page is full-bleed, without the top bar.
      expect(find.text(_strings.analysisResultTitle), findsNothing);

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows the result page once the paper is understood', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.text(_strings.analysisResultTitle), findsOneWidget);
      expect(find.byType(AnalysisProgressView), findsNothing);
      // The first section §4 asks for, drawn from the analysis (F07-T02).
      expect(find.byType(ResultHeaderCard), findsOneWidget);
      expect(find.text(invoiceAnalysis().title), findsOneWidget);
      // …followed by the second (F07-T03).
      expect(find.byType(ResultSummaryCard), findsOneWidget);
      expect(find.text(invoiceAnalysis().summary.short), findsOneWidget);
    });

    testWidgets('the back control leaves the result', (tester) async {
      var closed = 0;
      await cubit.analyze();
      await pumpScreen(tester, onClose: () => closed++);

      await tester.tap(find.byTooltip(_strings.analysisResultBackLabel));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('lays out under Large Text and in English', (tester) async {
      await cubit.analyze();
      await pumpScreen(
        tester,
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a state page instead of a result when it fails', (
      tester,
    ) async {
      // Which page each failure gets is covered in `service_state_test.dart`;
      // this only pins that the screen switches faces at all.
      repository.answer = const Err(AnalysisServiceFailure());
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.text(_strings.analysisFailedTitle), findsOneWidget);
      expect(find.byType(ResultHeaderCard), findsNothing);

      repository.answer = null;
      await tester.tap(find.text(_strings.actionRetry));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.byType(ResultHeaderCard), findsOneWidget);
    });
  });

  group('a partially understood paper', () {
    testWidgets('is topped with a banner saying so', (tester) async {
      repository.answer = Ok(invoiceAnalysis(status: AnalysisStatus.partial));
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.byType(PartialResultBanner), findsOneWidget);
      expect(find.text(_strings.resultPartialBanner), findsOneWidget);
    });

    testWidgets('still shows everything it did understand', (tester) async {
      repository.answer = Ok(invoiceAnalysis(status: AnalysisStatus.partial));
      await cubit.analyze();
      await pumpScreen(tester);

      // A half-read paper is worth showing — the part the user came for is
      // usually in it.
      expect(find.byType(ResultHeaderCard), findsOneWidget);
      expect(find.byType(ResultSummaryCard), findsOneWidget);
    });

    testWidgets('says nothing extra about a full result', (tester) async {
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.byType(PartialResultBanner), findsNothing);
    });
  });

  group('a paper the app cannot explain', () {
    setUp(() => repository.answer = const Err(UnsupportedDocumentFailure()));

    testWidgets('says so in its own words, not as a generic failure', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.text(_strings.analysisUnsupportedTitle), findsOneWidget);
      expect(find.text(_strings.analysisUnsupportedMessage), findsOneWidget);
      expect(find.text(_strings.analysisFailedTitle), findsNothing);
    });

    testWidgets('does not offer a retry that would cost an analysis', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      // The same text would come back unsupported again, and the user would
      // pay one of their three daily analyses to find out.
      expect(find.text(_strings.actionRetry), findsNothing);
    });

    testWidgets('falls through to the text the phone already read', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedTextOnlyView), findsOneWidget);
      expect(find.text(_extraction.text.cleanedText), findsOneWidget);
      expect(find.text(_strings.extractedTextOnlyNote), findsOneWidget);
    });

    testWidgets('comes back from that text to the state page', (tester) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.analysisResultBackLabel));
      await tester.pumpAndSettle();

      expect(find.text(_strings.analysisUnsupportedTitle), findsOneWidget);
    });

    testWidgets('lays out under Large Text and in English', (tester) async {
      await cubit.analyze();
      await pumpScreen(
        tester,
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
