import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/accessibility/high_contrast_cubit.dart';
import 'package:war2aty/core/accessibility/text_size_cubit.dart';
import 'package:war2aty/core/accessibility/usecases/get_high_contrast.dart';
import 'package:war2aty/core/accessibility/usecases/get_text_size.dart';
import 'package:war2aty/core/accessibility/usecases/set_high_contrast.dart';
import 'package:war2aty/core/accessibility/usecases/set_text_size.dart';
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
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/usecases/watch_upcoming_reminder.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/usecases/cleanup_analysis_session.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_image.dart';
import 'package:war2aty/features/analysis/domain/usecases/ocr_image.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/cubit/ocr_review_cubit.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/correct_perspective.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/ocr_engine.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_candidates.dart';
import 'package:war2aty/features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';

import '../support/fakes.dart';

const _strings = ArStrings();
const _imagePath = '/tmp/paper.jpg';

/// Always fails, on either route — the online route is what this suite
/// exercises, but [analyze] is wired too, so a regression that routed a
/// retry through the offline path would show up as a non-zero count instead
/// of going unnoticed.
final class _AlwaysFailingAnalysisRepository implements AnalysisRepository {
  int analyzeCalls = 0;
  int analyzeImageCalls = 0;
  int ocrImageCalls = 0;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    analyzeCalls++;
    return const Err(AnalysisServiceFailure());
  }

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyzeImage(
    AnalysisImageRequest request,
  ) async {
    analyzeImageCalls++;
    return const Err(AnalysisServiceFailure());
  }

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    ocrImageCalls++;
    return const Err(AnalysisServiceFailure());
  }
}

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  late bool ocrEngineConstructed;
  late bool ocrProcessingCubitConstructed;

  /// Boots the real app — real DI wiring, real router — up to the point where
  /// a photo is ready to preview, with connectivity forced online (F13's
  /// [FakeConnectivityService] default) so [ImagePreviewCubit.proceed] takes
  /// the online branch.
  ///
  /// `OcrEngine` and `OcrProcessingCubit` are registered as poisoned: either
  /// one being resolved — which is the only way Tesseract can ever run —
  /// flips a flag this test asserts against, instead of letting a silent
  /// fallback pass unnoticed.
  Future<_AlwaysFailingAnalysisRepository> pumpToOnlinePreview(
    WidgetTester tester,
  ) async {
    ocrEngineConstructed = false;
    ocrProcessingCubitConstructed = false;

    final onboarding = FakeOnboardingRepository(seen: true);
    // azureOcrEnabled: true — this test exercises the online route
    // specifically (its whole point is proving no silent OCR fallback once
    // online is chosen), so the pipeline must actually be live.
    final usage = FakeUsageRepository(
      seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
    );
    addTearDown(usage.dispose);
    final documents = FakeRecentDocumentsRepository();
    addTearDown(documents.dispose);
    final reminders = FakeUpcomingReminderRepository();
    addTearDown(reminders.dispose);
    final repository = _AlwaysFailingAnalysisRepository();

    getIt
      ..registerFactory<LocaleCubit>(() {
        final store = FakeLocaleStore();
        return LocaleCubit(
          getSavedLocale: GetSavedLocale(store),
          setLocale: SetLocale(store),
        );
      })
      ..registerFactory<BootstrapCubit>(
        () => BootstrapCubit(InitializeApp(const [])),
      )
      ..registerLazySingleton<OnboardingCubit>(
        () => OnboardingCubit(
          hasSeenOnboarding: HasSeenOnboarding(onboarding),
          completeOnboarding: CompleteOnboarding(onboarding),
        ),
      )
      ..registerFactory<HomeCubit>(
        () => HomeCubit(
          watchDailyUsage: WatchDailyUsage(usage),
          watchRecentDocuments: WatchRecentDocuments(documents),
          watchUpcomingReminder: WatchUpcomingReminder(reminders),
        ),
      )
      // WaraqtiApp mounts these unconditionally (F11) — not this suite's
      // concern, but they must resolve for the app to build at all.
      ..registerFactory<TextSizeCubit>(() {
        final store = FakeTextSizeStore();
        return TextSizeCubit(
          getTextSize: GetTextSize(store),
          setTextSize: SetTextSize(store),
        );
      })
      ..registerFactory<HighContrastCubit>(() {
        final store = FakeHighContrastStore();
        return HighContrastCubit(
          getHighContrast: GetHighContrast(store),
          setHighContrast: SetHighContrast(store),
        );
      })
      // Online by default (`FakeConnectivityService`'s default is connected),
      // a corrector that hands the photo back untouched, good-quality fakes
      // for rotate/assess so `confirm()` proceeds without the quality sheet.
      ..registerFactoryParam<ImagePreviewCubit, String, void>(
        (path, _) => ImagePreviewCubit(
          source: CapturedPhoto(path),
          rotate: RotateImage(FakeImageRotator()),
          assessQuality: AssessImageQuality(FakeImageQualityService()),
          decideRoute: DecideAnalysisRoute(FakeConnectivityService(), usage),
          correctPerspective: CorrectPerspective(FakePerspectiveCorrector()),
          createSession: CreateAnalysisSession(FakeAnalysisSessionStorage()),
          onlineHandoff: getIt(),
          ocrHandoff: getIt(),
          cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
        ),
      )
      ..registerLazySingleton<ImageAnalysisSessionHolder>(
        ImageAnalysisSessionHolder.new,
      )
      ..registerLazySingleton<OcrSessionHolder>(OcrSessionHolder.new)
      ..registerLazySingleton<AnalysisRepository>(() => repository)
      ..registerFactory<AnalyzeDocument>(() => AnalyzeDocument(getIt()))
      ..registerFactory<AnalyzeImage>(() => AnalyzeImage(getIt()))
      ..registerFactory<OcrImage>(() => OcrImage(getIt()))
      ..registerFactoryParam<OcrReviewCubit, AnalysisSession, CapturedPhoto>(
        (session, photo) => OcrReviewCubit(
          session: session,
          photo: photo,
          ocrImage: getIt(),
          extractCandidates: getIt(),
          // Unset (default) — allowed, same reasoning as the result cubit's
          // registration below: this suite is not exercising consent.
          getAnalysisConsent: GetAnalysisConsent(FakeAnalysisConsentStore()),
          imageHolder: getIt(),
        ),
      )
      ..registerFactory<BuildAnalysisResult>(BuildAnalysisResult.new)
      ..registerFactoryParam<
        AnalysisResultCubit,
        AnalysisSession,
        AnalysisSource
      >(
        (session, source) => AnalysisResultCubit(
          session: session,
          source: source,
          // Unset (default) — GetAnalysisConsent reads this as allowed, so
          // this suite's failure/retry flow isn't blocked by a declined
          // consent state it isn't testing.
          getAnalysisConsent: GetAnalysisConsent(FakeAnalysisConsentStore()),
          analyzeDocument: getIt(),
          analyzeImage: getIt(),
          buildResult: getIt(),
          syncDailyUsage: SyncDailyUsage(usage),
        ),
      )
      // The result route also mounts these two (F09 save, F10 audio reader) —
      // not this suite's concern, but the router builds them unconditionally,
      // so they must resolve for the failure page underneath to render at all.
      ..registerFactoryParam<SaveDocumentCubit, AnalysisSession, void>((
        session,
        _,
      ) {
        final documents = FakeDocumentsRepository();
        return SaveDocumentCubit(
          SaveDocument(documents),
          SaveDocumentWithImage(documents),
          sessionId: session.id,
          cleanupSession: CleanupAnalysisSession(FakeAnalysisSessionStorage()),
        );
      })
      ..registerFactory<AudioReaderCubit>(() {
        final tts = FakeTextToSpeechService();
        return AudioReaderCubit(
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
          GetDefaultReadingSpeed(FakeDefaultReadingSpeedStore()),
          GetDefaultReadingVoice(FakeDefaultReadingVoiceStore()),
        );
      })
      // Denied — retaking after a failed OCR review lands on the permission
      // gate, never the viewfinder, which keeps this suite from also needing
      // a working `CameraCaptureCubit`.
      ..registerFactory<CameraPermissionCubit>(() {
        final permissions = FakeCameraPermissionRepository(
          status: PermissionOutcome.denied,
        );
        return CameraPermissionCubit(
          getCameraPermission: GetCameraPermission(permissions),
          requestCameraPermission: RequestCameraPermission(permissions),
          openPermissionSettings: OpenPermissionSettings(permissions),
        );
      })
      // Real extractors — `OcrReviewCubit.buildReviewedResult` is not this
      // suite's concern, but the cubit still needs one to construct.
      ..registerFactory<ExtractCandidates>(
        () => ExtractCandidates(
          normalizer: TextNormalizer(),
          dateExtractor: const DateExtractor(),
          timeExtractor: const TimeExtractor(),
          amountExtractor: const AmountExtractor(),
          phoneExtractor: const PhoneExtractor(),
          referenceExtractor: const ReferenceExtractor(),
        ),
      )
      // Poisoned (F13-T16): the online route must never reach either of
      // these, whether on the first attempt or on any retry.
      ..registerLazySingleton<OcrEngine>(() {
        ocrEngineConstructed = true;
        throw StateError(
          'OcrEngine/Tesseract must never be constructed once the online '
          'route is chosen — a failure must retry the online request, not '
          'fall back to on-device OCR.',
        );
      })
      ..registerFactoryParam<OcrProcessingCubit, AnalysisSession, void>((_, _) {
        ocrProcessingCubitConstructed = true;
        throw StateError(
          'OcrProcessingCubit must never be constructed once the online '
          'route is chosen — the /ocr route must not be reachable from a '
          'failed online analysis.',
        );
      })
      ..registerLazySingleton<GoRouter>(
        () => createAppRouter(onboardingGate: getIt()),
      );

    await tester.pumpWidget(const WaraqtiApp());
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets(
    'a failed online OCR review never constructs Tesseract, even when the '
    'user retakes',
    (tester) async {
      final repository = await pumpToOnlinePreview(tester);

      getIt<GoRouter>().go(AppRoutes.previewWith(_imagePath));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.previewUseImage));
      await tester.pumpAndSettle();

      // Landed on the OCR review screen's failure page (F14) — Azure OCR
      // itself failed, so /result and Groq are never reached.
      expect(find.text(_strings.ocrErrorTitle), findsOneWidget);
      expect(getIt<GoRouter>().state.uri.toString(), AppRoutes.ocrReview);
      expect(repository.ocrImageCalls, 1);
      expect(repository.analyzeImageCalls, 0);
      expect(repository.analyzeCalls, 0);

      // Retaking leaves the online route for a fresh capture — never a
      // silent hop to the offline (/ocr) Tesseract screen, and never an
      // automatic re-request of the same failing call.
      await tester.tap(find.text(_strings.ocrRetake));
      await tester.pumpAndSettle();

      expect(
        getIt<GoRouter>().state.uri.toString(),
        startsWith(AppRoutes.capture),
      );
      expect(repository.ocrImageCalls, 1);
      expect(repository.analyzeImageCalls, 0);
      expect(repository.analyzeCalls, 0);
      expect(
        ocrEngineConstructed,
        isFalse,
        reason: 'Tesseract must never be constructed on a failed online run',
      );
      expect(ocrProcessingCubitConstructed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
