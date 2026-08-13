import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_image.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:war2aty/features/analysis/presentation/widgets/extracted_text_only_view.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';

import '../../../support/fakes.dart';
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

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyzeImage(
    AnalysisImageRequest request,
  ) async {
    calls++;
    return answer ?? Ok(invoiceAnalysis());
  }

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    throw UnimplementedError('AnalysisResultCubit never calls ocrImage');
  }
}

void main() {
  late _FakeRepository repository;
  late FakeAnalysisConsentStore consentStore;
  late AnalysisResultCubit cubit;

  late FakeTextToSpeechService tts;
  late AudioReaderCubit audioReaderCubit;

  setUp(() {
    repository = _FakeRepository();
    consentStore = FakeAnalysisConsentStore();
    cubit = AnalysisResultCubit(
      session: _session,
      source: const OcrAnalysisSource(_extraction),
      getAnalysisConsent: GetAnalysisConsent(consentStore),
      analyzeDocument: AnalyzeDocument(repository),
      analyzeImage: AnalyzeImage(repository),
      buildResult: const BuildAnalysisResult(),
    );
    tts = FakeTextToSpeechService();
    audioReaderCubit = AudioReaderCubit(
      StartReading(
        const BuildReadingText(),
        const SelectVoiceForReading(),
        tts,
      ),
      StopReading(tts),
      PauseReading(tts),
      ResumeReading(tts),
      SetReadingSpeed(tts),
      WatchReadingEvents(tts),
    );
  });

  tearDown(() async {
    await cubit.close();
    await audioReaderCubit.close();
    await tts.dispose();
  });

  Future<void> pumpFailure(
    WidgetTester tester,
    AppFailure failure, {
    VoidCallback? onClose,
    VoidCallback? onListen,
    VoidCallback? onCaptureAnother,
    VoidCallback? onOpenSettings,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) async {
    repository.answer = Err(failure);
    await cubit.analyze();
    await pumpApp(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AnalysisResultCubit>.value(value: cubit),
          BlocProvider<AudioReaderCubit>.value(value: audioReaderCubit),
        ],
        child: AnalysisResultScreen(
          onClose: onClose,
          onListen: onListen,
          onCaptureAnother: onCaptureAnother,
          onOpenSettings: onOpenSettings,
        ),
      ),
      locale: locale,
      textScaler: textScaler,
    );
  }

  /// Pumps the declined-consent state directly, bypassing [pumpFailure]'s
  /// `repository.answer` — the cubit itself never calls the repository once
  /// consent is off, so there is nothing for that field to script.
  Future<void> pumpConsentDeclined(
    WidgetTester tester, {
    VoidCallback? onOpenSettings,
  }) async {
    await consentStore.writeConsent(false);
    await cubit.analyze();
    await pumpApp(
      tester,
      BlocProvider<AnalysisResultCubit>.value(
        value: cubit,
        child: AnalysisResultScreen(onOpenSettings: onOpenSettings),
      ),
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

  group('a declined analysis consent (F11-T02)', () {
    testWidgets('says analysis is off, not a generic failure', (tester) async {
      await pumpConsentDeclined(tester);

      expect(find.text(_strings.analysisConsentDeclinedTitle), findsOneWidget);
      expect(
        find.text(_strings.analysisConsentDeclinedMessage),
        findsOneWidget,
      );
      expect(find.text(_strings.analysisFailedTitle), findsNothing);
    });

    testWidgets('never asked the repository for anything', (tester) async {
      await pumpConsentDeclined(tester);

      expect(repository.calls, 0);
    });

    testWidgets('offers no retry that would only fail the same way', (
      tester,
    ) async {
      await pumpConsentDeclined(tester);

      expect(find.text(_strings.actionRetry), findsNothing);
    });

    testWidgets('leads with Settings when it can open it', (tester) async {
      var opened = 0;
      await pumpConsentDeclined(tester, onOpenSettings: () => opened++);

      await tester.tap(find.text(_strings.analysisConsentDeclinedOpenSettings));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('still offers the text the phone already read', (tester) async {
      var opened = 0;
      await pumpConsentDeclined(tester, onOpenSettings: () => opened++);

      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedTextOnlyView), findsOneWidget);
      expect(find.text(_extraction.text.cleanedText), findsOneWidget);
    });

    testWidgets('falls back to the text when Settings has nowhere to open', (
      tester,
    ) async {
      // No `onOpenSettings` wired (e.g. reached outside the router) — the
      // page still leads somewhere useful rather than a dead button.
      await pumpConsentDeclined(tester);

      expect(
        find.text(_strings.analysisConsentDeclinedOpenSettings),
        findsNothing,
      );
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
