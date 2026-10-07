import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/documents/usecases/save_document.dart';
import 'package:war2aty/core/documents/usecases/save_document_with_image.dart';
import 'package:war2aty/core/documents/usecases/watch_recent_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/usecases/discard_analysis_session.dart';
import 'package:war2aty/core/theme/app_theme.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_raw_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';

import '../features/analysis/analysis_fixtures.dart';
import '../support/fakes.dart';

const _ar = ArStrings();

const _session = AnalysisSession(id: 'session-1', imagePath: '/tmp/paper.jpg');

const _extraction = ExtractionResult(
  text: NormalizedOcrText(
    originalText: 'فاتورة كهرباء ٢٥٠',
    cleanedText: 'فاتورة كهرباء 250',
  ),
);

final class _FakeAnalysisRepository implements AnalysisRepository {
  _FakeAnalysisRepository(this.answer);

  final Result<DocumentAnalysis, AppFailure> answer;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async => answer;

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) => throw UnimplementedError('the result route never reads an image');
}

/// F26-T04: the remaining-analyses SnackBar after leaving the result page.
///
/// Through the real router, because the bug lived there: the count was stored
/// by the back arrow's `onClose` alone, so every other way out — the camera
/// and gallery actions, the reminder flow ending on a tab — showed nothing.
void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// Boots the real router at Home, then opens the result page over the
  /// shell, as the OCR review does. Two of three analyses are used up.
  Future<GoRouter> pumpResult(
    WidgetTester tester, {
    Result<DocumentAnalysis, AppFailure>? answer,
  }) async {
    final usage = FakeUsageRepository(seed: usageWith(limit: 3, remaining: 1));
    addTearDown(usage.dispose);
    final recentDocuments = FakeRecentDocumentsRepository();
    addTearDown(recentDocuments.dispose);
    final upcomingReminders = FakeUpcomingReminderRepository();
    addTearDown(upcomingReminders.dispose);
    final tts = FakeTextToSpeechService();
    addTearDown(tts.dispose);
    final repository = _FakeAnalysisRepository(answer ?? Ok(invoiceAnalysis()));

    getIt
      ..registerFactory<HomeCubit>(
        () => HomeCubit(
          watchDailyUsage: WatchDailyUsage(usage),
          watchRecentDocuments: WatchRecentDocuments(recentDocuments),
          watchUpcomingReminder: WatchUpcomingReminder(upcomingReminders),
        ),
      )
      ..registerLazySingleton<OcrSessionHolder>(OcrSessionHolder.new)
      ..registerLazySingleton<UsageHintHolder>(UsageHintHolder.new)
      ..registerFactory<GetDailyUsage>(() => GetDailyUsage(usage))
      ..registerFactoryParam<
        AnalysisResultCubit,
        AnalysisSession,
        AnalysisSource
      >(
        (session, source) => AnalysisResultCubit(
          session: session,
          source: source,
          getAnalysisConsent: GetAnalysisConsent(FakeAnalysisConsentStore()),
          analyzeDocument: AnalyzeDocument(repository),
          buildResult: const BuildAnalysisResult(),
          syncDailyUsage: SyncDailyUsage(usage),
          getDailyUsage: GetDailyUsage(usage),
          discardSession: DiscardAnalysisSession(FakeAnalysisSessionStorage()),
        ),
      )
      ..registerFactory<SaveDocumentCubit>(() {
        final documents = FakeDocumentsRepository();
        return SaveDocumentCubit(
          SaveDocument(documents),
          SaveDocumentWithImage(documents),
        );
      })
      ..registerFactory<AudioReaderCubit>(
        () => AudioReaderCubit(
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
        ),
      )
      // Denied: «صوّر ورقة تانية» lands on the permission gate, which is
      // enough to cover the shell without a working camera.
      ..registerFactory<CameraPermissionCubit>(() {
        final permissions = FakeCameraPermissionRepository(
          status: PermissionOutcome.denied,
        );
        return CameraPermissionCubit(
          getCameraPermission: GetCameraPermission(permissions),
          requestCameraPermission: RequestCameraPermission(permissions),
          openPermissionSettings: OpenPermissionSettings(permissions),
        );
      });
    getIt<OcrSessionHolder>().set(_session, _extraction);

    final onboarding = OnboardingCubit(
      hasSeenOnboarding: HasSeenOnboarding(
        FakeOnboardingRepository(seen: true),
      ),
      completeOnboarding: CompleteOnboarding(
        FakeOnboardingRepository(seen: true),
      ),
    );
    await onboarding.load();

    final router = createAppRouter(onboardingGate: onboarding);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppLocalizations.arabic,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.delegates,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.result));
    await tester.pumpAndSettle();
    return router;
  }

  final hint = find.text(_ar.homeUsageRemaining(1));

  testWidgets('the back arrow shows the count on Home', (tester) async {
    final router = await pumpResult(tester);

    await tester.tap(find.byTooltip(_ar.analysisResultBackLabel));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.home);
    expect(hint, findsOneWidget);
  });

  testWidgets('the system back shows the count on Home', (tester) async {
    final router = await pumpResult(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.home);
    expect(hint, findsOneWidget);
  });

  testWidgets(
    'leaving for a tab another way shows the count there — as the reminder '
    'flow does, ending on the reminders tab or Home',
    (tester) async {
      final router = await pumpResult(tester);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(hint, findsOneWidget);
    },
  );

  testWidgets(
    '«صوّر ورقة تانية» holds the count off the camera, then shows it on Home',
    (tester) async {
      final router = await pumpResult(
        tester,
        answer: const Err(UnsupportedDocumentFailure()),
      );

      await tester.tap(find.text(_ar.analysisCaptureAnother));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), startsWith(AppRoutes.capture));
      expect(hint, findsNothing);
      expect(getIt<UsageHintHolder>().consume(), 1, reason: 'held, not lost');
    },
  );

  testWidgets('the held count shows once the camera is left', (tester) async {
    final router = await pumpResult(
      tester,
      answer: const Err(UnsupportedDocumentFailure()),
    );

    await tester.tap(find.text(_ar.analysisCaptureAnother));
    await tester.pumpAndSettle();
    expect(hint, findsNothing);

    router.pop();
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppRoutes.home);
    expect(hint, findsOneWidget);
  });

  testWidgets('a new result drops a count still held from the last one', (
    tester,
  ) async {
    final router = await pumpResult(
      tester,
      answer: const Err(UnsupportedDocumentFailure()),
    );
    await tester.tap(find.text(_ar.analysisCaptureAnother));
    await tester.pumpAndSettle();

    // Straight on to the next result, the camera still underneath.
    unawaited(router.push(AppRoutes.result));
    await tester.pumpAndSettle();

    expect(getIt<UsageHintHolder>().consume(), isNull);
  });
}
