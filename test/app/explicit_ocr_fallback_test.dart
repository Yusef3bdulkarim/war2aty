import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/notifications/reminder_notification_taps.dart';
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
import 'package:war2aty/core/usage/usage_hint_holder.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/watch_daily_usage.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/ocr_image.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/cubit/ocr_review_cubit.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_raw_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/capture/domain/usecases/request_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_permission_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/home/presentation/cubit/home_cubit.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_candidates.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_document_text.dart';
import 'package:war2aty/features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';
import 'package:war2aty/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:war2aty/features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'package:war2aty/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';

import '../support/fakes.dart';

const _strings = ArStrings();
const _imagePath = '/tmp/paper.jpg';

/// Fails the online reading with [ocrFailure]. [analyze] is wired too and
/// always fails, so a regression that reached the analysis from the review
/// screen would show up as a non-zero count instead of going unnoticed.
final class _FakeAnalysisRepository implements AnalysisRepository {
  _FakeAnalysisRepository(this.ocrFailure);

  final AppFailure ocrFailure;
  int analyzeCalls = 0;
  int ocrImageCalls = 0;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    analyzeCalls++;
    return const Err(AnalysisServiceFailure());
  }

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    ocrImageCalls++;
    return Err(ocrFailure);
  }
}

/// The on-device reader (Tesseract, behind [OcrRepository]). Counts every
/// run, so a test can assert it ran exactly once — or never.
///
/// Counted at run time, not construction: since F20-T22 `OcrReviewCubit`
/// takes `ExtractDocumentText` on every online review, so the reader is
/// always constructed; what the allowlist governs is whether it RUNS.
final class _CountingDeviceOcr implements OcrRepository {
  int runs = 0;

  @override
  Future<Result<OcrResult, AppFailure>> recognizeText(String imagePath) async {
    runs++;
    return const Ok(OcrResult(originalText: 'فاتورة كهرباء المبلغ 850 جنيه'));
  }
}

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  late _CountingDeviceOcr deviceOcr;
  late bool ocrProcessingCubitConstructed;

  /// Boots the real app — real DI wiring, real router — up to the point where
  /// a photo is ready to preview, with connectivity forced online (F13's
  /// [FakeConnectivityService] default) so [ImagePreviewCubit.proceed] takes
  /// the online branch, and the online reading failing with [onlineFailure].
  ///
  /// The on-device reader is counted ([deviceOcr]) and `OcrProcessingCubit`
  /// is poisoned: those are the only ways Tesseract can run, so a fallback
  /// the allowlist does not permit — or one that runs twice — cannot pass
  /// unnoticed. [consent] seeds the analysis-consent store (`null` = never
  /// asked, which reads as allowed).
  Future<_FakeAnalysisRepository> pumpToOnlinePreview(
    WidgetTester tester, {
    required AppFailure onlineFailure,
    bool? consent,
  }) async {
    deviceOcr = _CountingDeviceOcr();
    ocrProcessingCubitConstructed = false;

    final onboarding = FakeOnboardingRepository(seen: true);
    // onlineOcrEnabled: true — this test exercises the online route
    // specifically (its whole point is proving no silent OCR fallback once
    // online is chosen), so the pipeline must actually be live.
    final usage = FakeUsageRepository(
      seed: usageWith(limit: 3, remaining: 3, onlineOcrEnabled: true),
    );
    addTearDown(usage.dispose);
    final documents = FakeRecentDocumentsRepository();
    addTearDown(documents.dispose);
    final reminders = FakeUpcomingReminderRepository();
    addTearDown(reminders.dispose);
    final repository = _FakeAnalysisRepository(onlineFailure);

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
          cropImage: CropImage(FakeImageCropper()),
          assessQuality: AssessImageQuality(FakeImageQualityService()),
          decideRoute: DecideAnalysisRoute(FakeConnectivityService(), usage),
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
      ..registerFactory<OcrImage>(() => OcrImage(getIt()))
      ..registerFactoryParam<OcrReviewCubit, AnalysisSession, CapturedPhoto>(
        (session, photo) => OcrReviewCubit(
          session: session,
          photo: photo,
          ocrImage: getIt(),
          extractCandidates: getIt(),
          getAnalysisConsent: GetAnalysisConsent(
            FakeAnalysisConsentStore(consent),
          ),
          imageHolder: getIt(),
          extractDocumentText: ExtractDocumentText(deviceOcr),
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
          buildResult: getIt(),
          syncDailyUsage: SyncDailyUsage(usage),
          getDailyUsage: GetDailyUsage(usage),
        ),
      )
      // The result route also mounts these two (F09 save, F10 audio reader) —
      // not this suite's concern, but the router builds them unconditionally,
      // so they must resolve for the failure page underneath to render at all.
      ..registerFactory<SaveDocumentCubit>(() {
        final documents = FakeDocumentsRepository();
        return SaveDocumentCubit(
          SaveDocument(documents),
          SaveDocumentWithImage(documents),
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
          StartRawReading(const SelectVoiceForReading(), tts),
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
      // Real extractors — the fallback extracts candidates from the device
      // text with them, exactly as the offline route does.
      ..registerFactory<ExtractCandidates>(
        () => const ExtractCandidates(
          normalizer: TextNormalizer(),
          dateExtractor: DateExtractor(),
          timeExtractor: TimeExtractor(),
          amountExtractor: AmountExtractor(),
          phoneExtractor: PhoneExtractor(),
          referenceExtractor: ReferenceExtractor(),
        ),
      )
      // Poisoned (F13-T16): the online route must never reach the /ocr
      // screen, whether on the first attempt or on any retry.
      ..registerFactoryParam<OcrProcessingCubit, AnalysisSession, void>((_, _) {
        ocrProcessingCubitConstructed = true;
        throw StateError(
          'OcrProcessingCubit must never be constructed once the online '
          'route is chosen — the /ocr route must not be reachable from a '
          'failed online analysis.',
        );
      })
      ..registerLazySingleton<UsageHintHolder>(UsageHintHolder.new)
      ..registerLazySingleton<ReminderNotificationTaps>(
        ReminderNotificationTaps.new,
      )
      ..registerLazySingleton<GoRouter>(
        () => createAppRouter(onboardingGate: getIt()),
      );

    await tester.pumpWidget(const WaraqtiApp());
    await tester.pumpAndSettle();
    return repository;
  }

  /// Opens the preview and taps «استخدم الصورة», which takes the online route.
  Future<void> useImage(WidgetTester tester) async {
    getIt<GoRouter>().go(AppRoutes.previewWith(_imagePath));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_strings.previewUseImage));
    await tester.pumpAndSettle();
  }

  // F20 §1: the four failures the device can work around (O3, O4, O5/O10,
  // O7). Each reads the page on the phone exactly once and warns about it.
  const allowlisted = <String, AppFailure>{
    'rate limited (O3)': AiProviderRateLimitFailure(),
    'timed out (O4)': RequestTimeoutFailure(),
    'online reading unavailable (O5/O10)': OnlineOcrUnavailableFailure(),
    'offline (O7)': NoInternetFailure(),
  };

  for (final MapEntry(key: row, value: failure) in allowlisted.entries) {
    testWidgets(
      '$row: Tesseract runs exactly once and the fallback banner shows',
      (tester) async {
        final repository = await pumpToOnlinePreview(
          tester,
          onlineFailure: failure,
        );

        await useImage(tester);

        // Still on the review screen — a review of the phone's reading, not
        // the error page and not the offline /ocr screen.
        expect(getIt<GoRouter>().state.uri.toString(), AppRoutes.ocrReview);
        expect(find.text(_strings.ocrOnlineFallbackWarning), findsOneWidget);
        expect(find.text(_strings.ocrOfflineQualityWarning), findsNothing);
        expect(find.text(_strings.ocrErrorTitle), findsNothing);
        expect(find.text(_strings.ocrOnlineAnalyze), findsOneWidget);

        expect(repository.ocrImageCalls, 1);
        expect(deviceOcr.runs, 1);
        expect(repository.analyzeCalls, 0);
        expect(ocrProcessingCubitConstructed, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an online failure outside the allowlist never runs Tesseract, even '
    'when the user retakes',
    (tester) async {
      // O6/O11: a deploy fault must surface, not hide behind a weaker read.
      final repository = await pumpToOnlinePreview(
        tester,
        onlineFailure: const AnalysisServiceFailure(),
      );

      await useImage(tester);

      // Landed on the OCR review screen's failure page (F14) — the online
      // reading itself failed, so /result and the analysis are never reached.
      expect(find.text(_strings.ocrErrorTitle), findsOneWidget);
      expect(getIt<GoRouter>().state.uri.toString(), AppRoutes.ocrReview);
      expect(repository.ocrImageCalls, 1);
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
      expect(repository.analyzeCalls, 0);
      expect(
        deviceOcr.runs,
        0,
        reason:
            'Tesseract must never run for an online failure outside the '
            'F20 §1 allowlist',
      );
      expect(ocrProcessingCubitConstructed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a declined consent sends nothing and never runs Tesseract (O8)',
    (tester) async {
      // Even with an allowlisted failure queued: consent is checked before
      // the online reading, so there is no failure to fall back from.
      final repository = await pumpToOnlinePreview(
        tester,
        onlineFailure: const NoInternetFailure(),
        consent: false,
      );

      await useImage(tester);

      expect(getIt<GoRouter>().state.uri.toString(), AppRoutes.ocrReview);
      expect(find.text(_strings.analysisConsentDeclinedTitle), findsOneWidget);
      expect(repository.ocrImageCalls, 0, reason: 'no network call');
      expect(deviceOcr.runs, 0, reason: 'no Tesseract either');
      expect(repository.analyzeCalls, 0);
      expect(ocrProcessingCubitConstructed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
