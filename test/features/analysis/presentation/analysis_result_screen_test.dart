import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/widgets/audio_mini_player_bar.dart';
import 'package:war2aty/core/widgets/audio_options_sheet.dart';
import 'package:war2aty/core/widgets/partial_result_banner.dart';
import 'package:war2aty/core/widgets/result_actions_card.dart';
import 'package:war2aty/core/widgets/result_details_card.dart';
import 'package:war2aty/core/widgets/result_hero_scroll_view.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/screens/analysis_result_screen.dart';
import 'package:war2aty/features/analysis/presentation/widgets/analysis_progress_view.dart';
import 'package:war2aty/features/analysis/presentation/widgets/extracted_text_only_view.dart';
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

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    throw UnimplementedError('AnalysisResultCubit never calls ocrImage');
  }
}

void main() {
  late _FakeRepository repository;
  late AnalysisResultCubit cubit;
  late FakeTextToSpeechService tts;
  late AudioReaderCubit audioReaderCubit;
  late FakeDefaultReadingSpeedStore speedStore;

  setUp(() {
    repository = _FakeRepository();
    cubit = AnalysisResultCubit(
      session: _session,
      source: const OcrAnalysisSource(_extraction),
      getAnalysisConsent: GetAnalysisConsent(FakeAnalysisConsentStore()),
      analyzeDocument: AnalyzeDocument(repository),
      buildResult: const BuildAnalysisResult(),
      syncDailyUsage: SyncDailyUsage(FakeUsageRepository()),
      getDailyUsage: GetDailyUsage(FakeUsageRepository()),
    );
    tts = FakeTextToSpeechService();
    speedStore = FakeDefaultReadingSpeedStore();
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
      GetDefaultReadingSpeed(speedStore),
      GetDefaultReadingVoice(FakeDefaultReadingVoiceStore()),
    );
  });

  tearDown(() async {
    await cubit.close();
    await audioReaderCubit.close();
    await tts.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onClose,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    bool settle = true,
  }) => pumpApp(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider<AnalysisResultCubit>.value(value: cubit),
        BlocProvider<AudioReaderCubit>.value(value: audioReaderCubit),
      ],
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
      // The lens reads for as long as the wait lasts: nothing settles.
      await pumpScreen(tester, settle: false);

      expect(find.byType(AnalysisProgressView), findsOneWidget);
      expect(
        find.textContaining(_strings.analysisWaitStepType, findRichText: true),
        findsOneWidget,
      );
      // No way out mid-analysis: the page is full-bleed, without the top bar.
      expect(find.bySemanticsLabel(_strings.analysisResultTitle), findsNothing);

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('gives the finish its beat before showing the result', (
      tester,
    ) async {
      repository.gate = Completer<void>();
      unawaited(cubit.analyze());
      await pumpScreen(tester, settle: false);
      await tester.pump(const Duration(seconds: 6));

      repository.gate!.complete();
      await tester.pump();

      // The answer is in, but the check gets its moment first (F22 #10).
      expect(find.byType(AnalysisProgressView), findsOneWidget);
      expect(find.bySemanticsLabel(_strings.analysisResultTitle), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AnalysisProgressView), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.byType(AnalysisProgressView), findsNothing);
      expect(
        find.bySemanticsLabel(_strings.analysisResultTitle),
        findsOneWidget,
      );
    });

    testWidgets('one haptic when the result arrives, none on a failure', (
      tester,
    ) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
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

      // A failure first: no haptic (F22 #11).
      repository
        ..gate = Completer<void>()
        ..answer = const Err(AnalysisServiceFailure());
      unawaited(cubit.analyze());
      await pumpScreen(tester, settle: false);
      await tester.pump(const Duration(seconds: 2));
      repository.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(haptics, isEmpty);

      // Then a retry that succeeds: exactly one.
      repository
        ..gate = Completer<void>()
        ..answer = Ok(invoiceAnalysis());
      unawaited(cubit.analyze());
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      repository.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(
        find.bySemanticsLabel(_strings.analysisResultTitle),
        findsOneWidget,
      );
    });

    testWidgets('a failure replaces the progress page at once, lens halted', (
      tester,
    ) async {
      repository
        ..gate = Completer<void>()
        ..answer = const Err(AnalysisServiceFailure());
      unawaited(cubit.analyze());
      await pumpScreen(tester, settle: false);
      await tester.pump(const Duration(seconds: 4));

      repository.gate!.complete();
      await tester.pump();

      expect(find.byType(AnalysisProgressView), findsNothing);
      expect(find.text(_strings.analysisFailedTitle), findsOneWidget);
    });

    testWidgets('shows the result page once the paper is understood', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      expect(
        find.bySemanticsLabel(_strings.analysisResultTitle),
        findsOneWidget,
      );
      expect(find.byType(AnalysisProgressView), findsNothing);
      // The summary is the hero now (F21 #14).
      expect(find.byType(ResultHeroScrollView), findsOneWidget);
      expect(find.text(_strings.resultSummaryLabel), findsOneWidget);
      expect(find.text(invoiceAnalysis().summary.short), findsOneWidget);
      // No type card and no title (F21 #15): the type is the first row of
      // the details card instead.
      expect(find.text(invoiceAnalysis().title), findsNothing);
      expect(find.byType(ResultDetailsCard), findsOneWidget);
      expect(find.text(_strings.documentKindInvoice), findsOneWidget);
    });

    testWidgets('draws information, amounts and dates as one card, once', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      // Three §4 sections, one card — not one per section.
      expect(find.byType(ResultDetailsCard), findsOneWidget);
      expect(find.text(_strings.resultKeyInformationTitle), findsOneWidget);
      expect(find.text(_strings.resultAmountsTitle), findsOneWidget);
      expect(find.text(_strings.resultDatesTitle), findsOneWidget);
    });

    testWidgets('puts the warnings right before the explanation', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      final warning = tester.getRect(
        find.text(invoiceAnalysis().warnings.single.text),
      );
      // The fixture's last cards before the explanation are its instructions.
      final instructions = tester.getRect(
        find.text(invoiceAnalysis().instructions.single, findRichText: true),
      );
      final explanation = tester.getRect(
        find.text(_strings.resultShowExplanation),
      );
      expect(instructions.bottom, lessThan(warning.top));
      expect(warning.bottom, lessThan(explanation.top));
    });

    testWidgets('keeps the cards 12 px apart', (tester) async {
      await cubit.analyze();
      await pumpScreen(tester);

      // The drawn surfaces, not the widgets: each card carries its own gap.
      Rect surface(Type card) => tester.getRect(
        find
            .descendant(
              of: find.byType(card),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      final actions = surface(ResultActionsCard);
      final details = surface(ResultDetailsCard);
      expect(details.top - actions.bottom, moreOrLessEquals(12));
    });

    testWidgets('offers to listen without needing an external onListen', (
      tester,
    ) async {
      // Unlike the state-page fallback, the ready result's reader is
      // self-contained — no callback needs wiring for the button to appear.
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.text(_strings.resultListen), findsOneWidget);
    });

    testWidgets('the back control leaves the result', (tester) async {
      var closed = 0;
      await cubit.analyze();
      await pumpScreen(tester, onClose: () => closed++);

      await tester.tap(find.byTooltip(_strings.analysisResultBackLabel));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('the system back gesture leaves the same way as the arrow', (
      tester,
    ) async {
      var closed = 0;
      await cubit.analyze();
      await pumpScreen(tester, onClose: () => closed++);

      // Android's back button / gesture, and iOS's edge swipe via the router.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(closed, 1);
      expect(find.byType(ResultDetailsCard), findsOneWidget);
    });

    testWidgets('the bar is a lone arrow, but the page still has a heading', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      // No printed title (F21 locked decision #4)…
      expect(find.text(_strings.analysisResultTitle), findsNothing);
      // …but a screen reader still lands on the page's name as a heading.
      final heading = tester.getSemantics(
        find.bySemanticsLabel(_strings.analysisResultTitle),
      );
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(heading.rect.height, greaterThan(0));
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
      expect(find.byType(ResultDetailsCard), findsNothing);

      repository.answer = null;
      await tester.tap(find.text(_strings.actionRetry));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.byType(ResultDetailsCard), findsOneWidget);
    });
  });

  group('the mini-player (F10-T03)', () {
    testWidgets(
      'opens the mode sheet and starts the bar with what was picked',
      (tester) async {
        await cubit.analyze();
        await pumpScreen(tester);

        await tester.tap(find.text(_strings.resultListen));
        await tester.pumpAndSettle();

        expect(find.byType(AudioOptionsSheet), findsOneWidget);
        await tester.tap(find.text(_strings.audioReaderModeFull));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
        await tester.pumpAndSettle();

        expect(find.byType(AudioOptionsSheet), findsNothing);
        expect(find.byType(AudioMiniPlayerBar), findsOneWidget);
        expect(
          find.text(
            _strings.audioReaderNowReading(_strings.audioReaderModeFull),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a fresh open highlights the persisted default speed (F11-T07)',
      (tester) async {
        await speedStore.writeSpeed(ReadingSpeed.faster);
        await cubit.analyze();
        await pumpScreen(tester);

        await tester.tap(find.text(_strings.resultListen));
        await tester.pumpAndSettle();
        // Confirm without touching the speed row — the default should carry
        // straight through to the engine.
        await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
        await tester.pumpAndSettle();

        expect(tts.speechRates, [ReadingSpeed.faster.rate]);
      },
    );

    testWidgets('the extracted-text panel opens the same sheet', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      final expandToggle = find.text(_strings.resultShowExtractedText);
      await tester.ensureVisible(expandToggle);
      await tester.tap(expandToggle);
      await tester.pumpAndSettle();

      final listenButton = find.text(_strings.resultListenToText);
      await tester.ensureVisible(listenButton);
      await tester.tap(listenButton);
      await tester.pumpAndSettle();

      expect(find.byType(AudioOptionsSheet), findsOneWidget);
    });

    testWidgets('stopping removes the bar', (tester) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();
      expect(find.byType(AudioMiniPlayerBar), findsOneWidget);

      await tester.tap(find.byTooltip(_strings.audioReaderStopLabel));
      await tester.pumpAndSettle();

      expect(find.byType(AudioMiniPlayerBar), findsNothing);
    });

    testWidgets('«خيارات» reopens the sheet on the mode already reading', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(_strings.audioReaderModeSummaryAndKeyInformation),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.audioReaderOptions));
      await tester.pumpAndSettle();
      // Confirming straight away keeps reading the same mode.
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(
        find.text(
          _strings.audioReaderNowReading(
            _strings.audioReaderModeSummaryAndKeyInformation,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dismissing the sheet without a mode starts nothing', (
      tester,
    ) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(AudioMiniPlayerBar), findsNothing);
    });
  });

  group('the mini-player really speaks (F10-T04)', () {
    testWidgets('confirming a mode actually speaks its text', (tester) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_strings.audioReaderModeFull));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(tts.spoken, [invoiceAnalysis().summary.detailed]);
    });

    testWidgets('stopping actually silences the engine', (tester) async {
      await cubit.analyze();
      await pumpScreen(tester);

      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_strings.audioReaderStopLabel));
      await tester.pumpAndSettle();

      expect(tts.stopCount, 1);
    });

    testWidgets(
      'a picked mode that fails to speak reports it instead of showing a bar',
      (tester) async {
        tts.speakFails = true;
        await cubit.analyze();
        await pumpScreen(tester);

        await tester.tap(find.text(_strings.resultListen));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
        await tester.pumpAndSettle();

        expect(find.byType(AudioMiniPlayerBar), findsNothing);
        expect(find.text(_strings.audioReaderFailedFeedback), findsOneWidget);
      },
    );
  });

  group('the mini-player pauses and resumes (F10-T05)', () {
    Future<void> startReading(WidgetTester tester) async {
      await cubit.analyze();
      await pumpScreen(tester);
      await tester.tap(find.text(_strings.resultListen));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();
    }

    testWidgets('the toggle pauses the engine and offers to resume', (
      tester,
    ) async {
      await startReading(tester);

      await tester.tap(find.byTooltip(_strings.audioReaderPauseLabel));
      await tester.pumpAndSettle();

      expect(tts.pauseCount, 1);
      expect(find.byTooltip(_strings.audioReaderResumeLabel), findsOneWidget);
    });

    testWidgets('tapping it again resumes the engine', (tester) async {
      await startReading(tester);
      await tester.tap(find.byTooltip(_strings.audioReaderPauseLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_strings.audioReaderResumeLabel));
      await tester.pumpAndSettle();

      expect(tts.resumeCount, 1);
      expect(find.byTooltip(_strings.audioReaderPauseLabel), findsOneWidget);
    });

    testWidgets('stopping while paused still silences the engine', (
      tester,
    ) async {
      await startReading(tester);
      await tester.tap(find.byTooltip(_strings.audioReaderPauseLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_strings.audioReaderStopLabel));
      await tester.pumpAndSettle();

      expect(tts.stopCount, 1);
      expect(find.byType(AudioMiniPlayerBar), findsNothing);
    });

    testWidgets('starting a fresh reading is never paused', (tester) async {
      await startReading(tester);
      await tester.tap(find.byTooltip(_strings.audioReaderPauseLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.audioReaderOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(find.byTooltip(_strings.audioReaderPauseLabel), findsOneWidget);
    });
  });

  group('a partially understood paper', () {
    testWidgets('is flagged with a banner saying so', (tester) async {
      repository.answer = Ok(invoiceAnalysis(status: AnalysisStatus.partial));
      await cubit.analyze();
      await pumpScreen(tester);

      expect(find.byType(PartialResultBanner), findsOneWidget);
      expect(find.text(_strings.resultPartialBanner), findsOneWidget);
    });

    testWidgets('puts that banner right before the data', (tester) async {
      repository.answer = Ok(invoiceAnalysis(status: AnalysisStatus.partial));
      await cubit.analyze();
      await pumpScreen(tester);

      final summary = tester.getRect(
        find.text(invoiceAnalysis().summary.short),
      );
      final warning = tester.getRect(
        find.text(invoiceAnalysis().warnings.single.text),
      );
      final banner = tester.getRect(find.byType(PartialResultBanner));
      final data = tester.getRect(find.byType(ResultDetailsCard));

      // Not at the top any more (F21 #17): the summary comes first. The
      // warnings now come after the data (F21 #21).
      expect(summary.bottom, lessThan(banner.top));
      expect(banner.bottom, lessThanOrEqualTo(data.top));
      expect(warning.top, greaterThan(data.bottom));
    });

    testWidgets('still shows everything it did understand', (tester) async {
      repository.answer = Ok(invoiceAnalysis(status: AnalysisStatus.partial));
      await cubit.analyze();
      await pumpScreen(tester);

      // A half-read paper is worth showing — the part the user came for is
      // usually in it.
      expect(find.byType(ResultDetailsCard), findsOneWidget);
      expect(find.text(invoiceAnalysis().summary.short), findsOneWidget);
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
