import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/document_analysis.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/build_analysis_result.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:war2aty/features/analysis/presentation/widgets/extracted_text_only_view.dart';
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
  int calls = 0;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    calls++;
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

  Future<void> pumpFailure(
    WidgetTester tester,
    AppFailure failure, {
    VoidCallback? onClose,
    VoidCallback? onListen,
    VoidCallback? onCaptureAnother,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) async {
    repository.answer = Err(failure);
    await cubit.analyze();
    await pumpApp(
      tester,
      BlocProvider<AnalysisResultCubit>.value(
        value: cubit,
        child: AnalysisResultScreen(
          onClose: onClose,
          onListen: onListen,
          onCaptureAnother: onCaptureAnother,
        ),
      ),
      locale: locale,
      textScaler: textScaler,
    );
  }

  group('no internet', () {
    testWidgets('says the connection is what is missing', (tester) async {
      await pumpFailure(tester, const NoInternetFailure());

      expect(find.text(_strings.analysisNoInternetTitle), findsOneWidget);
      expect(find.text(_strings.analysisNoInternetMessage), findsOneWidget);
    });

    testWidgets('leads with a retry, since connections come back', (
      tester,
    ) async {
      await pumpFailure(tester, const NoInternetFailure());

      repository.answer = null;
      await tester.tap(find.text(_strings.actionRetry));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text(_strings.analysisNoInternetTitle), findsNothing);
    });

    testWidgets('still offers the text the phone already read', (tester) async {
      await pumpFailure(tester, const NoInternetFailure());

      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedTextOnlyView), findsOneWidget);
      expect(find.text(_extraction.text.cleanedText), findsOneWidget);
    });
  });

  group('the daily limit', () {
    final failure = DailyLimitReachedFailure(DateTime.utc(2026, 8, 26));

    testWidgets('says the day is spent and what is still possible', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      expect(find.text(_strings.analysisLimitReachedTitle), findsOneWidget);
      expect(find.text(_strings.analysisLimitReachedMessage), findsOneWidget);
    });

    testWidgets('offers no retry that could only fail again', (tester) async {
      await pumpFailure(tester, failure);

      expect(find.text(_strings.actionRetry), findsNothing);
    });

    testWidgets('leads with the text instead — which costs no analysis', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedTextOnlyView), findsOneWidget);
      // The OCR already ran on the phone; nothing was spent showing this.
      expect(repository.calls, 1);
    });

    testWidgets('offers to read it aloud once there is a reader', (
      tester,
    ) async {
      var listened = 0;
      await pumpFailure(tester, failure, onListen: () => listened++);

      await tester.tap(find.text(_strings.resultListenToExtractedText));
      await tester.pumpAndSettle();

      expect(listened, 1);
    });

    testWidgets('leaves listening out while there is no reader', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      expect(find.text(_strings.resultListenToExtractedText), findsNothing);
    });
  });

  group('a service problem', () {
    testWidgets('says so once, whichever way the service failed', (
      tester,
    ) async {
      await pumpFailure(tester, const AnalysisServiceFailure());
      expect(find.text(_strings.analysisFailedTitle), findsOneWidget);

      await pumpFailure(tester, const RequestTimeoutFailure());
      expect(find.text(_strings.analysisFailedTitle), findsOneWidget);

      await pumpFailure(tester, const InvalidAnalysisResponseFailure());
      expect(find.text(_strings.analysisFailedTitle), findsOneWidget);
    });

    testWidgets('offers a retry and the text', (tester) async {
      await pumpFailure(tester, const AnalysisServiceFailure());

      expect(find.text(_strings.actionRetry), findsOneWidget);
      expect(find.text(_strings.resultShowExtractedText), findsOneWidget);
    });
  });

  group('every state page', () {
    testWidgets('offers a way back home', (tester) async {
      var closed = 0;
      await pumpFailure(
        tester,
        const AnalysisServiceFailure(),
        onClose: () => closed++,
      );

      await tester.tap(find.text(_strings.analysisBackToHome));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('lets an unsupported paper be swapped for another', (
      tester,
    ) async {
      var captured = 0;
      await pumpFailure(
        tester,
        const UnsupportedDocumentFailure(),
        onCaptureAnother: () => captured++,
      );

      await tester.tap(find.text(_strings.analysisCaptureAnother));
      await tester.pumpAndSettle();

      expect(captured, 1);
    });

    testWidgets('lays out under Large Text and in English', (tester) async {
      await pumpFailure(
        tester,
        const NoInternetFailure(),
        locale: AppLocalizations.english,
        textScaler: const TextScaler.linear(2),
      );

      expect(
        find.text(const EnStrings().analysisNoInternetTitle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
