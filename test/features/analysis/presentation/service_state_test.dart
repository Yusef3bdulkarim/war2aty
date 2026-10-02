import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:war2aty/features/analysis/presentation/widgets/extracted_text_only_view.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/analysis_steps_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/consent_value_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/extracted_text_entry_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/failure_note_chip.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/failure_tips_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/limit_reset_card.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/privacy_text_note.dart';
import 'package:war2aty/features/analysis/presentation/widgets/failure/supported_documents_section.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_raw_reading.dart';
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
      buildResult: const BuildAnalysisResult(),
      syncDailyUsage: SyncDailyUsage(FakeUsageRepository()),
      getDailyUsage: GetDailyUsage(FakeUsageRepository()),
    );
    tts = FakeTextToSpeechService();
    audioReaderCubit = AudioReaderCubit(
      StartReading(
        const BuildReadingText(),
        const SelectVoiceForReading(),
        tts,
      ),
      StartRawReading(const SelectVoiceForReading(), tts),
      StopReading(tts),
      PauseReading(tts),
      ResumeReading(tts),
      SetReadingSpeed(tts),
      WatchReadingEvents(tts),
      GetDefaultReadingSpeed(FakeDefaultReadingSpeedStore()),
      GetDefaultReadingVoice(FakeDefaultReadingVoiceStore()),
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
    VoidCallback? onCaptureAnother,
    VoidCallback? onPickFromGallery,
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
          onCaptureAnother: onCaptureAnother,
          onPickFromGallery: onPickFromGallery,
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
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) async {
    await consentStore.writeConsent(false);
    await cubit.analyze();
    await pumpApp(
      tester,
      BlocProvider<AnalysisResultCubit>.value(
        value: cubit,
        child: AnalysisResultScreen(onOpenSettings: onOpenSettings),
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

    testWidgets('shows what is done, the explanation waiting (F23-T09)', (
      tester,
    ) async {
      await pumpFailure(tester, const NoInternetFailure());

      final steps = tester.widget<AnalysisStepsCard>(
        find.byType(AnalysisStepsCard),
      );
      expect(steps.explanation, ExplanationStep.waiting);
      expect(
        find.bySemanticsLabel(
          _strings.analysisStepsSemantics(
            _strings.analysisStepWaitingForInternet,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('then the three things to check, under the steps', (
      tester,
    ) async {
      await pumpFailure(tester, const NoInternetFailure());

      final tips = tester.widget<FailureTipsCard>(find.byType(FailureTipsCard));
      expect(tips.title, _strings.analysisNoInternetTipsTitle);
      expect(tips.tips.map((t) => t.text), [
        _strings.analysisNoInternetTipWifi,
        _strings.analysisNoInternetTipAirplane,
        _strings.analysisNoInternetTipSignal,
      ]);
      expect(
        tester.getRect(find.byType(FailureTipsCard)).top,
        greaterThan(tester.getRect(find.byType(AnalysisStepsCard)).bottom),
      );
    });

    testWidgets('makes no claim the attempt did not count (F23 #6)', (
      tester,
    ) async {
      await pumpFailure(tester, const NoInternetFailure());

      expect(find.byType(FailureNoteChip), findsNothing);
    });

    testWidgets('keeps retry, text and home, and nothing for a new paper', (
      tester,
    ) async {
      await pumpFailure(
        tester,
        const NoInternetFailure(),
        onCaptureAnother: () {},
        onPickFromGallery: () {},
      );

      expect(
        find.widgetWithText(FilledButton, _strings.actionRetry),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, _strings.resultShowExtractedText),
        findsOneWidget,
      );
      expect(find.text(_strings.analysisBackToHome), findsOneWidget);
      expect(find.text(_strings.analysisCaptureAnother), findsNothing);
      expect(find.byType(SupportedDocumentsSection), findsNothing);
    });

    testWidgets('fits a small phone at 2.0× text, in English too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await pumpFailure(
          tester,
          const NoInternetFailure(),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
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

    testWidgets('offers no listening (F23 #12)', (tester) async {
      await pumpFailure(tester, failure);

      expect(find.text(_strings.resultListenToText), findsNothing);
      expect(find.text(_strings.resultListen), findsNothing);
    });

    testWidgets('counts down to the failure\'s own reset (F23-T10)', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      final card = tester.widget<LimitResetCard>(find.byType(LimitResetCard));
      expect(card.resetAt, failure.resetAtCairo);
      // No cached usage in this suite: no number, so no pill.
      expect(card.dailyLimit, isNull);
    });

    testWidgets('then what can be done now: read the text, come back', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      final tips = tester.widget<FailureTipsCard>(find.byType(FailureTipsCard));
      expect(tips.title, _strings.analysisLimitTipsTitle);
      expect(tips.tips.map((t) => t.text), [
        _strings.analysisLimitTipReadText,
        _strings.analysisLimitTipTomorrow,
      ]);
      expect(
        tester.getRect(find.byType(FailureTipsCard)).top,
        greaterThan(tester.getRect(find.byType(LimitResetCard)).bottom),
      );
    });

    testWidgets('names the limit when the cache knows it', (tester) async {
      final usage = FakeUsageRepository(
        seed: usageWith(limit: 3, remaining: 0),
      );
      addTearDown(usage.dispose);
      final limitCubit = AnalysisResultCubit(
        session: _session,
        source: const OcrAnalysisSource(_extraction),
        getAnalysisConsent: GetAnalysisConsent(consentStore),
        analyzeDocument: AnalyzeDocument(repository),
        buildResult: const BuildAnalysisResult(),
        syncDailyUsage: SyncDailyUsage(usage),
        getDailyUsage: GetDailyUsage(usage),
      );
      addTearDown(limitCubit.close);
      repository.answer = Err(failure);
      await limitCubit.analyze();
      await pumpApp(
        tester,
        BlocProvider<AnalysisResultCubit>.value(
          value: limitCubit,
          child: const AnalysisResultScreen(),
        ),
      );

      expect(
        find.text(_strings.analysisLimitReachedMessageWithLimit(3)),
        findsOneWidget,
      );
      expect(find.text(_strings.analysisLimitUsedOf(3)), findsOneWidget);
    });

    testWidgets('fits a small phone at 2.0× text, in English too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await pumpFailure(
          tester,
          failure,
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
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

    testWidgets('shows the explanation as the step that did not finish', (
      tester,
    ) async {
      await pumpFailure(tester, const AnalysisServiceFailure());

      final steps = tester.widget<AnalysisStepsCard>(
        find.byType(AnalysisStepsCard),
      );
      expect(steps.explanation, ExplanationStep.failed);
      expect(
        find.bySemanticsLabel(
          _strings.analysisStepsSemantics(_strings.analysisStepNotFinished),
        ),
        findsOneWidget,
      );
    });

    testWidgets('then what to try if it happens again (F23-T11)', (
      tester,
    ) async {
      await pumpFailure(tester, const RequestTimeoutFailure());

      final tips = tester.widget<FailureTipsCard>(find.byType(FailureTipsCard));
      expect(tips.title, _strings.analysisFailedTipsTitle);
      expect(tips.tips.map((t) => t.text), [
        _strings.analysisFailedTipWait,
        _strings.analysisFailedTipConnection,
        _strings.analysisFailedTipReadText,
      ]);
      expect(
        tester.getRect(find.byType(FailureTipsCard)).top,
        greaterThan(tester.getRect(find.byType(AnalysisStepsCard)).bottom),
      );
    });

    testWidgets('makes no claim the attempt did not count (F23 #8)', (
      tester,
    ) async {
      await pumpFailure(tester, const RequestTimeoutFailure());

      expect(find.byType(FailureNoteChip), findsNothing);
    });

    testWidgets('a retry that works replaces the whole page', (tester) async {
      await pumpFailure(tester, const AnalysisServiceFailure());

      repository.answer = null;
      await tester.tap(find.text(_strings.actionRetry));
      await tester.pumpAndSettle();

      expect(find.byType(AnalysisStepsCard), findsNothing);
      expect(find.byType(FailureTipsCard), findsNothing);
    });

    testWidgets('fits a small phone at 2.0× text, in English too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await pumpFailure(
          tester,
          const AnalysisServiceFailure(),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });
  });

  group('a declined analysis consent (F11-T02)', () {
    testWidgets('shows what turning it on would give (F23-T12)', (
      tester,
    ) async {
      await pumpConsentDeclined(tester, onOpenSettings: () {});

      expect(find.byType(ConsentValueCard), findsOneWidget);
    });

    testWidgets('then what happens to the text, under the tiles', (
      tester,
    ) async {
      await pumpConsentDeclined(tester, onOpenSettings: () {});

      expect(find.text(_strings.privacyPointTextOnly), findsOneWidget);
      expect(
        tester.getRect(find.byType(PrivacyTextNote)).top,
        greaterThan(tester.getRect(find.byType(ConsentValueCard)).bottom),
      );
    });

    testWidgets('fits a small phone at 2.0× text, in English too (F23-T13)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await pumpConsentDeclined(
          tester,
          onOpenSettings: () {},
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });

    testWidgets('switches nothing itself: no toggle on the page', (
      tester,
    ) async {
      await pumpConsentDeclined(tester, onOpenSettings: () {});

      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(FailureNoteChip), findsNothing);
      expect(find.byType(AnalysisStepsCard), findsNothing);
    });

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

    testWidgets('or for one from the gallery (F23-T07)', (tester) async {
      var picked = 0;
      await pumpFailure(
        tester,
        const UnsupportedDocumentFailure(),
        onPickFromGallery: () => picked++,
      );

      await tester.tap(find.text(_strings.analysisPickFromGallery));
      await tester.pumpAndSettle();

      expect(picked, 1);
    });

    testWidgets('offers the gallery on no other page', (tester) async {
      await pumpFailure(
        tester,
        const NoInternetFailure(),
        onPickFromGallery: () {},
      );

      expect(find.text(_strings.analysisPickFromGallery), findsNothing);
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

  group('an unsupported paper, Option B (F23-T08)', () {
    const failure = UnsupportedDocumentFailure();

    testWidgets('says the attempt did not count', (tester) async {
      await pumpFailure(tester, failure);

      expect(find.byType(FailureNoteChip), findsOneWidget);
      expect(find.text(_strings.analysisAttemptNotCounted), findsOneWidget);
    });

    testWidgets('shows the text card above the papers it explains', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      final card = tester.getRect(find.byType(ExtractedTextEntryCard));
      final papers = tester.getRect(find.byType(SupportedDocumentsSection));
      expect(papers.top, greaterThan(card.bottom));
    });

    testWidgets('the text card opens what was read', (tester) async {
      await pumpFailure(tester, failure);

      await tester.tap(find.byType(ExtractedTextEntryCard));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractedTextOnlyView), findsOneWidget);
      expect(find.text(_extraction.text.cleanedText), findsOneWidget);
    });

    testWidgets('puts camera and gallery side by side, home below', (
      tester,
    ) async {
      var captured = 0;
      var picked = 0;
      await pumpFailure(
        tester,
        failure,
        onCaptureAnother: () => captured++,
        onPickFromGallery: () => picked++,
      );

      final camera = tester.getCenter(
        find.text(_strings.analysisCaptureAnother),
      );
      final gallery = tester.getCenter(
        find.text(_strings.analysisPickFromGallery),
      );
      final home = tester.getCenter(find.text(_strings.analysisBackToHome));
      expect(camera.dy, moreOrLessEquals(gallery.dy));
      // RTL: the camera leads, on the right.
      expect(camera.dx, greaterThan(gallery.dx));
      expect(home.dy, greaterThan(camera.dy));

      await tester.tap(find.text(_strings.analysisCaptureAnother));
      await tester.tap(find.text(_strings.analysisPickFromGallery));
      expect((captured, picked), (1, 1));
    });

    testWidgets('no longer offers the text as a button', (tester) async {
      await pumpFailure(
        tester,
        failure,
        onCaptureAnother: () {},
        onPickFromGallery: () {},
      );

      expect(
        find.widgetWithText(FilledButton, _strings.resultShowExtractedText),
        findsNothing,
      );
    });

    testWidgets('with nowhere to capture, home leads and is not repeated', (
      tester,
    ) async {
      await pumpFailure(tester, failure);

      expect(
        find.widgetWithText(FilledButton, _strings.analysisBackToHome),
        findsOneWidget,
      );
      expect(find.text(_strings.analysisBackToHome), findsOneWidget);
    });

    testWidgets('leaves the text card out when nothing was read', (
      tester,
    ) async {
      final emptyCubit = AnalysisResultCubit(
        session: _session,
        source: const OcrAnalysisSource(
          ExtractionResult(
            text: NormalizedOcrText(originalText: '', cleanedText: ''),
          ),
        ),
        getAnalysisConsent: GetAnalysisConsent(consentStore),
        analyzeDocument: AnalyzeDocument(repository),
        buildResult: const BuildAnalysisResult(),
        syncDailyUsage: SyncDailyUsage(FakeUsageRepository()),
        getDailyUsage: GetDailyUsage(FakeUsageRepository()),
      );
      addTearDown(emptyCubit.close);
      repository.answer = const Err(failure);
      await emptyCubit.analyze();
      await pumpApp(
        tester,
        BlocProvider<AnalysisResultCubit>.value(
          value: emptyCubit,
          child: const AnalysisResultScreen(),
        ),
      );

      expect(find.byType(ExtractedTextEntryCard), findsNothing);
      expect(find.byType(SupportedDocumentsSection), findsOneWidget);
    });

    testWidgets('fits a small phone at 2.0× text, in English too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final locale in AppLocalizations.supportedLocales) {
        await pumpFailure(
          tester,
          failure,
          onCaptureAnother: () {},
          onPickFromGallery: () {},
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(tester.takeException(), isNull, reason: '$locale');
      }
    });
  });

  group('the quality gate fixes (F23-T13)', () {
    /// A failure page for a run whose OCR read nothing, with [usage] as the
    /// cached daily usage.
    Future<void> pumpWithoutText(
      WidgetTester tester,
      AppFailure failure, {
      FakeUsageRepository? usage,
      bool consentDeclined = false,
    }) async {
      final cache = usage ?? FakeUsageRepository();
      addTearDown(cache.dispose);
      final emptyCubit = AnalysisResultCubit(
        session: _session,
        source: const OcrAnalysisSource(
          ExtractionResult(
            text: NormalizedOcrText(originalText: '', cleanedText: ''),
          ),
        ),
        getAnalysisConsent: GetAnalysisConsent(consentStore),
        analyzeDocument: AnalyzeDocument(repository),
        buildResult: const BuildAnalysisResult(),
        syncDailyUsage: SyncDailyUsage(cache),
        getDailyUsage: GetDailyUsage(cache),
      );
      addTearDown(emptyCubit.close);
      if (consentDeclined) await consentStore.writeConsent(false);
      repository.answer = Err(failure);
      await emptyCubit.analyze();
      await pumpApp(
        tester,
        BlocProvider<AnalysisResultCubit>.value(
          value: emptyCubit,
          child: const AnalysisResultScreen(),
        ),
      );
    }

    testWidgets('the daily limit with no text offers home once', (
      tester,
    ) async {
      await pumpWithoutText(
        tester,
        DailyLimitReachedFailure(DateTime.utc(2026, 8, 26)),
      );

      expect(find.text(_strings.analysisBackToHome), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, _strings.analysisBackToHome),
        findsOneWidget,
      );
    });

    testWidgets('consent off, no Settings, no text: home once', (tester) async {
      await pumpWithoutText(
        tester,
        const AnalysisConsentDeclinedFailure(),
        consentDeclined: true,
      );

      expect(find.text(_strings.analysisBackToHome), findsOneWidget);
    });

    testWidgets('a cached limit of 0 is worded as unknown', (tester) async {
      await pumpWithoutText(
        tester,
        DailyLimitReachedFailure(DateTime.utc(2026, 8, 26)),
        usage: FakeUsageRepository(seed: usageWith(limit: 0, remaining: 0)),
      );

      expect(find.text(_strings.analysisLimitReachedMessage), findsOneWidget);
      expect(
        tester.widget<LimitResetCard>(find.byType(LimitResetCard)).dailyLimit,
        isNull,
      );
    });

    testWidgets('the text page offers copy alone, across the width', (
      tester,
    ) async {
      await pumpFailure(tester, const NoInternetFailure());
      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();

      expect(find.text(_strings.resultListenToText), findsNothing);
      final copy = tester.getSize(
        find.widgetWithText(FilledButton, _strings.actionCopy),
      );
      final page = tester.getSize(find.byType(ExtractedTextOnlyView));
      expect(copy.width, greaterThan(page.width * 0.8));
    });
  });
}
