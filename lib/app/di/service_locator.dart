import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/accessibility/high_contrast_cubit.dart';
import '../../core/accessibility/high_contrast_store.dart';
import '../../core/accessibility/text_size_cubit.dart';
import '../../core/accessibility/text_size_store.dart';
import '../../core/accessibility/usecases/get_high_contrast.dart';
import '../../core/accessibility/usecases/get_text_size.dart';
import '../../core/accessibility/usecases/set_high_contrast.dart';
import '../../core/accessibility/usecases/set_text_size.dart';
import '../../core/analysis/analysis_consent_store.dart';
import '../../core/analysis/processing_mode_store.dart';
import '../../core/analysis/usecases/get_analysis_consent.dart';
import '../../core/analysis/usecases/get_processing_mode.dart';
import '../../core/analysis/usecases/set_analysis_consent.dart';
import '../../core/analysis/usecases/set_processing_mode.dart';
import '../../core/audio/audio_reader_cubit.dart';
import '../../core/audio/default_reading_speed_store.dart';
import '../../core/audio/default_reading_voice_store.dart';
import '../../core/audio/resume_reading_enabled_store.dart';
import '../../core/audio/usecases/get_available_voices.dart';
import '../../core/audio/usecases/get_default_reading_speed.dart';
import '../../core/audio/usecases/get_default_reading_voice.dart';
import '../../core/audio/usecases/get_resume_reading_enabled.dart';
import '../../core/audio/usecases/preview_default_voice.dart';
import '../../core/audio/usecases/set_default_reading_speed.dart';
import '../../core/audio/usecases/set_default_reading_voice.dart';
import '../../core/audio/usecases/set_resume_reading_enabled.dart';
import '../../core/config/local_runtime_config_repository.dart';
import '../../core/config/runtime_config_repository.dart';
import '../../core/config/runtime_config_store.dart';
import '../../core/connectivity/connectivity_plus_service.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/crypto/aes_gcm_file_encryptor.dart';
import '../../core/crypto/document_encryption_key_store.dart';
import '../../core/crypto/file_encryptor.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/documents_dao.dart';
import '../../core/database/daos/reminders_dao.dart';
import '../../core/documents/document_image_store.dart';
import '../../core/documents/documents_repository.dart';
import '../../core/documents/drift_documents_repository.dart';
import '../../core/documents/file_document_image_store.dart';
import '../../core/documents/recent_documents_repository.dart';
import '../../core/documents/usecases/build_analysis_result.dart';
import '../../core/documents/usecases/delete_all_documents.dart';
import '../../core/documents/usecases/delete_document.dart';
import '../../core/documents/usecases/save_document.dart';
import '../../core/documents/usecases/save_document_with_image.dart';
import '../../core/documents/usecases/set_document_note.dart';
import '../../core/documents/usecases/update_document.dart';
import '../../core/documents/usecases/watch_document.dart';
import '../../core/documents/usecases/watch_documents.dart';
import '../../core/documents/usecases/watch_recent_documents.dart';
import '../../core/env/app_environment.dart';
import '../../core/env/usecases/get_app_version.dart';
import '../../core/identity/installation_id_provider.dart';
import '../../core/localization/locale_cubit.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/usecases/get_saved_locale.dart';
import '../../core/localization/usecases/set_locale.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_sink.dart';
import '../../core/network/api_client.dart';
import '../../core/permissions/notification_permission_repository.dart';
import '../../core/permissions/permission_handler_service.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/permissions/system_notification_permission_repository.dart';
import '../../core/permissions/usecases/get_notification_permission.dart';
import '../../core/permissions/usecases/open_notification_permission_settings.dart';
import '../../core/permissions/usecases/request_notification_permission.dart';
import '../../core/reminders/drift_reminders_repository.dart';
import '../../core/reminders/flutter_local_notifications_port.dart';
import '../../core/reminders/flutter_local_notifications_reminder_scheduler.dart';
import '../../core/reminders/local_notifications_port.dart';
import '../../core/reminders/notification_privacy_store.dart';
import '../../core/reminders/reminder_scheduler.dart';
import '../../core/reminders/reminders_repository.dart';
import '../../core/reminders/stub_upcoming_reminder_repository.dart';
import '../../core/reminders/upcoming_reminder_repository.dart';
import '../../core/reminders/usecases/complete_reminder.dart';
import '../../core/reminders/usecases/create_manual_reminder.dart';
import '../../core/reminders/usecases/create_reminder_from_document_date.dart';
import '../../core/reminders/usecases/delete_all_reminders.dart';
import '../../core/reminders/usecases/delete_reminder.dart';
import '../../core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import '../../core/reminders/usecases/set_hide_sensitive_notification_details.dart';
import '../../core/reminders/usecases/snooze_reminder.dart';
import '../../core/reminders/usecases/watch_reminder.dart';
import '../../core/reminders/usecases/watch_reminders.dart';
import '../../core/reminders/usecases/watch_upcoming_reminder.dart';
import '../../core/result/result.dart';
import '../../core/settings/app_settings_repository.dart';
import '../../core/settings/drift_app_settings_repository.dart';
import '../../core/settings/usecases/delete_all_app_data.dart';
import '../../core/storage/analysis_session.dart';
import '../../core/storage/analysis_session_storage.dart';
import '../../core/storage/flutter_secure_storage_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/storage/usecases/cleanup_analysis_session.dart';
import '../../core/usage/remote_usage_repository.dart';
import '../../core/usage/stub_usage_repository.dart';
import '../../core/usage/usage_remote_data_source.dart';
import '../../core/usage/usage_repository.dart';
import '../../core/usage/usecases/get_daily_usage.dart';
import '../../core/usage/usecases/sync_daily_usage.dart';
import '../../core/usage/usecases/watch_daily_usage.dart';
import '../../features/analysis/data/datasources/analysis_remote_data_source.dart';
import '../../features/analysis/data/datasources/disabled_analysis_remote_data_source.dart';
import '../../features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';
import '../../features/analysis/data/datasources/mock_analysis_remote_data_source.dart';
import '../../features/analysis/data/repositories/default_analysis_repository.dart';
import '../../features/analysis/domain/entities/analysis_source.dart';
import '../../features/analysis/domain/repositories/analysis_repository.dart';
import '../../features/analysis/domain/usecases/analyze_document.dart';
import '../../features/analysis/domain/usecases/analyze_image.dart';
import '../../features/analysis/domain/usecases/ocr_image.dart';
import '../../features/analysis/presentation/cubit/analysis_result_cubit.dart';
import '../../features/analysis/presentation/cubit/ocr_review_cubit.dart';
import '../../features/analysis/presentation/image_analysis_session_holder.dart';
import '../../features/audio_reader/data/services/flutter_tts_text_to_speech_service.dart';
import '../../features/audio_reader/domain/services/text_to_speech_service.dart';
import '../../features/audio_reader/domain/usecases/build_reading_text.dart';
import '../../features/audio_reader/domain/usecases/pause_reading.dart';
import '../../features/audio_reader/domain/usecases/resume_reading.dart';
import '../../features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import '../../features/audio_reader/domain/usecases/set_reading_speed.dart';
import '../../features/audio_reader/domain/usecases/start_reading.dart';
import '../../features/audio_reader/domain/usecases/stop_reading.dart';
import '../../features/audio_reader/domain/usecases/watch_reading_events.dart';
import '../../features/bootstrap/data/repositories/stub_auth_repository.dart';
import '../../features/bootstrap/data/repositories/supabase_auth_repository.dart';
import '../../features/bootstrap/domain/entities/bootstrap_stage.dart';
import '../../features/bootstrap/domain/repositories/auth_repository.dart';
import '../../features/bootstrap/domain/usecases/ensure_active_session.dart';
import '../../features/bootstrap/domain/usecases/initialize_app.dart';
import '../../features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import '../../features/capture/data/repositories/system_camera_permission_repository.dart';
import '../../features/capture/data/services/dart_image_quality_service.dart';
import '../../features/capture/data/services/doclens_perspective_corrector.dart';
import '../../features/capture/data/services/image_package_rotator.dart';
import '../../features/capture/data/services/io_capture_file_cleanup.dart';
import '../../features/capture/data/services/platform_camera_service.dart';
import '../../features/capture/data/services/system_image_picker_service.dart';
import '../../features/capture/domain/entities/captured_photo.dart';
import '../../features/capture/domain/repositories/camera_permission_repository.dart';
import '../../features/capture/domain/services/capture_file_cleanup.dart';
import '../../features/capture/domain/services/image_picker_service.dart';
import '../../features/capture/domain/services/image_quality_service.dart';
import '../../features/capture/domain/services/image_rotator.dart';
import '../../features/capture/domain/services/perspective_corrector.dart';
import '../../features/capture/domain/usecases/assess_image_quality.dart';
import '../../features/capture/domain/usecases/capture_photo.dart';
import '../../features/capture/domain/usecases/cleanup_capture_files.dart';
import '../../features/capture/domain/usecases/correct_perspective.dart';
import '../../features/capture/domain/usecases/create_analysis_session.dart';
import '../../features/capture/domain/usecases/decide_analysis_route.dart';
import '../../features/capture/domain/usecases/dispose_camera.dart';
import '../../features/capture/domain/usecases/get_camera_permission.dart';
import '../../features/capture/domain/usecases/initialize_camera.dart';
import '../../features/capture/domain/usecases/open_permission_settings.dart';
import '../../features/capture/domain/usecases/pick_image_from_gallery.dart';
import '../../features/capture/domain/usecases/request_camera_permission.dart';
import '../../features/capture/domain/usecases/rotate_image.dart';
import '../../features/capture/presentation/cubit/camera_capture_cubit.dart';
import '../../features/capture/presentation/cubit/camera_permission_cubit.dart';
import '../../features/capture/presentation/cubit/gallery_picker_cubit.dart';
import '../../features/capture/presentation/cubit/image_preview_cubit.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/ocr/data/repositories/device_ocr_repository.dart';
import '../../features/ocr/data/services/dart_image_preprocessor.dart';
import '../../features/ocr/data/services/tesseract_ocr_engine.dart';
import '../../features/ocr/domain/repositories/ocr_repository.dart';
import '../../features/ocr/domain/services/amount_extractor.dart';
import '../../features/ocr/domain/services/date_extractor.dart';
import '../../features/ocr/domain/services/image_preprocessor.dart';
import '../../features/ocr/domain/services/ocr_engine.dart';
import '../../features/ocr/domain/services/phone_extractor.dart';
import '../../features/ocr/domain/services/reference_extractor.dart';
import '../../features/ocr/domain/services/text_normalizer.dart';
import '../../features/ocr/domain/services/time_extractor.dart';
import '../../features/ocr/domain/usecases/extract_candidates.dart';
import '../../features/ocr/domain/usecases/extract_document_text.dart';
import '../../features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import '../../features/ocr/presentation/ocr_session_holder.dart';
import '../../features/onboarding/data/repositories/drift_onboarding_repository.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/onboarding/domain/usecases/complete_onboarding.dart';
import '../../features/onboarding/domain/usecases/has_seen_onboarding.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/reminders/presentation/cubit/reminder_details_cubit.dart';
import '../../features/reminders/presentation/cubit/reminder_form_cubit.dart';
import '../../features/reminders/presentation/cubit/reminders_cubit.dart';
import '../../features/reminders/presentation/models/reminder_from_document_args.dart';
import '../../features/saved_papers/presentation/cubit/document_details_cubit.dart';
import '../../features/saved_papers/presentation/cubit/documents_list_cubit.dart';
import '../../features/saved_papers/presentation/cubit/save_document_cubit.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../router/app_router.dart';

/// Global service locator.
final GetIt getIt = GetIt.instance;

/// Wires up all dependencies. Call once during [bootstrap], before `runApp`.
Future<void> configureDependencies(
  AppEnvironment env, {
  AppDatabase? database,
}) async {
  _registerCore(env);
  _registerDatabase(database);
  _registerLocalization();
  _registerAccessibility();
  _registerIdentity(env);
  _registerNetwork(env);
  _registerLaunch(env);
  _registerOnboarding();
  _registerHome();
  _registerCapture();
  _registerOcr();
  _registerAnalysis(env);
  _registerSavedPapers();
  _registerReminders();
  _registerAudioReader();
  _registerSettings();
  _registerRouting();
}

void _registerCore(AppEnvironment env) {
  getIt
    ..registerSingleton<AppEnvironment>(env)
    // Logging is verbose in dev, silent in prod (privacy-first default).
    ..registerLazySingleton<LogSink>(
      () => env.isDev ? const DeveloperLogSink() : const NoopLogSink(),
    )
    ..registerLazySingleton<AppLogger>(() => StructuredAppLogger(getIt()))
    ..registerSingleton<RuntimeConfigStore>(RuntimeConfigStore());
}

void _registerDatabase(AppDatabase? database) {
  getIt.registerSingleton<AppDatabase>(database ?? AppDatabase());
}

void _registerLocalization() {
  getIt
    ..registerLazySingleton<LocaleStore>(() => DriftLocaleStore(getIt()))
    ..registerFactory<GetSavedLocale>(() => GetSavedLocale(getIt()))
    ..registerFactory<SetLocale>(() => SetLocale(getIt()))
    ..registerFactory<LocaleCubit>(
      () => LocaleCubit(getSavedLocale: getIt(), setLocale: getIt()),
    );
}

void _registerAccessibility() {
  getIt
    ..registerLazySingleton<TextSizeStore>(() => DriftTextSizeStore(getIt()))
    ..registerFactory<GetTextSize>(() => GetTextSize(getIt()))
    ..registerFactory<SetTextSize>(() => SetTextSize(getIt()))
    ..registerFactory<TextSizeCubit>(
      () => TextSizeCubit(getTextSize: getIt(), setTextSize: getIt()),
    )
    // F11-T06. Same `app_settings` table.
    ..registerLazySingleton<HighContrastStore>(
      () => DriftHighContrastStore(getIt()),
    )
    ..registerFactory<GetHighContrast>(() => GetHighContrast(getIt()))
    ..registerFactory<SetHighContrast>(() => SetHighContrast(getIt()))
    ..registerFactory<HighContrastCubit>(
      () =>
          HighContrastCubit(getHighContrast: getIt(), setHighContrast: getIt()),
    );
}

void _registerIdentity(AppEnvironment env) {
  getIt
    ..registerLazySingleton<SecureStorageService>(
      FlutterSecureStorageService.new,
    )
    ..registerLazySingleton<InstallationIdProvider>(
      () => SecureInstallationIdProvider(getIt()),
    )
    // Real Supabase Anonymous Auth (F06-T14). An unconfigured build has no
    // Supabase client to talk to, so it keeps the offline stub — that path is
    // reached only by a prod build missing its dart-defines, and a launch that
    // hangs on a session would be worse than one that runs without a backend.
    ..registerLazySingleton<AuthRepository>(
      () => env.isConfigured
          ? SupabaseAuthRepository(Supabase.instance.client.auth)
          : StubAuthRepository(getIt(), getIt()),
    )
    ..registerFactory<EnsureActiveSession>(() => EnsureActiveSession(getIt()));
}

/// The single HTTP client for the Edge Functions (F06-T14).
///
/// Registered even when the build is unconfigured — it simply has nowhere to
/// point, and the datasources above it are swapped out instead, so nothing
/// downstream needs a null check.
void _registerNetwork(AppEnvironment env) {
  getIt.registerLazySingleton<Dio>(
    () => createApiClient(
      environment: env,
      logger: getIt(),
      // Read through the repository rather than captured once: the token
      // rotates, and a closure over a stale one would 401 forever.
      accessToken: () async {
        final session = await getIt<AuthRepository>().restoreSession();
        return session.valueOrNull?.accessToken;
      },
      refreshSession: () async {
        final refreshed = await getIt<AuthRepository>().refreshSession();
        return refreshed.valueOrNull?.accessToken;
      },
    ),
  );
}

void _registerLaunch(AppEnvironment env) {
  getIt
    ..registerLazySingleton<RuntimeConfigRepository>(
      () => LocalRuntimeConfigRepository(getIt()),
    )
    ..registerLazySingleton<AnalysisSessionStorage>(
      FileAnalysisSessionStorage.new,
    )
    ..registerLazySingleton<UsageRemoteDataSource>(
      () => EdgeFunctionUsageRemoteDataSource(getIt()),
    )
    // The backend owns the quota — it is the only party that can count across
    // re-installs and devices. The stub survives only for an unconfigured
    // build, where there is nothing to ask.
    ..registerLazySingleton<UsageRepository>(
      () => env.isConfigured
          ? RemoteUsageRepository(getIt(), getIt())
          : StubUsageRepository(
              getIt(),
              // Read lazily so the config loaded during launch is respected.
              dailyLimit: () =>
                  getIt<RuntimeConfigStore>().current.dailyAnalysisLimit,
            ),
    )
    ..registerFactory<InitializeApp>(
      () => InitializeApp(_buildLaunchSteps(), logger: getIt()),
    )
    ..registerFactory<BootstrapCubit>(() => BootstrapCubit(getIt()));
}

/// The ordered launch sequence.
///
/// Only the session is critical — without an identity nothing else can run.
/// Housekeeping steps are allowed to fail quietly rather than block the user
/// behind an error screen.
List<BootstrapStep> _buildLaunchSteps() {
  return [
    BootstrapStep(BootstrapStage.session, () async {
      final result = await getIt<EnsureActiveSession>()();
      return result.map<void>((_) {});
    }),
    BootstrapStep(BootstrapStage.config, () async {
      final result = await getIt<RuntimeConfigRepository>().load();
      if (result case Ok(:final value)) {
        getIt<RuntimeConfigStore>().update(value);
      }
      return result.map<void>((_) {});
    }, critical: false),
    BootstrapStep(BootstrapStage.cleanup, () async {
      final result = await getIt<AnalysisSessionStorage>()
          .deleteStaleSessions();
      return result.map<void>((_) {});
    }, critical: false),
    BootstrapStep(BootstrapStage.reminders, () async {
      // The plugin/timezone/channel setup (F09-T10) has to run before the
      // first `reconcile` ever schedules anything.
      await getIt<LocalNotificationsPort>().initialize();
      final result = await getIt<ReminderScheduler>().reconcile();
      return result.map<void>((_) {});
    }, critical: false),
    BootstrapStep(BootstrapStage.usage, () async {
      final result = await getIt<UsageRepository>().syncUsage();
      return result.map<void>((_) {});
    }, critical: false),
  ];
}

void _registerOnboarding() {
  getIt
    ..registerLazySingleton<OnboardingRepository>(
      () => DriftOnboardingRepository(getIt()),
    )
    ..registerFactory<HasSeenOnboarding>(() => HasSeenOnboarding(getIt()))
    ..registerFactory<CompleteOnboarding>(() => CompleteOnboarding(getIt()))
    // App-scoped, not a factory: the router's redirect reads this one instance.
    ..registerLazySingleton<OnboardingCubit>(
      () => OnboardingCubit(
        hasSeenOnboarding: getIt(),
        completeOnboarding: getIt(),
      ),
    );
}

void _registerHome() {
  getIt
    // The Drift-backed [DocumentsRepository] singleton registered in
    // `_registerSavedPapers` also answers Home's narrower "recent N" reads
    // (F08-T05) — one saved-documents source of truth, two ports onto it.
    ..registerLazySingleton<RecentDocumentsRepository>(
      getIt.call<DriftDocumentsRepository>,
    )
    ..registerFactory<WatchDailyUsage>(() => WatchDailyUsage(getIt()))
    // Settings' «حدود الاستخدام» row (F11-T12) — a one-shot snapshot rather
    // than `WatchDailyUsage`'s live stream, registered next to it.
    ..registerFactory<GetDailyUsage>(() => GetDailyUsage(getIt()))
    // Called by `AnalysisResultCubit` after a successful analysis so Home's
    // live stream above reflects the freshly consumed slot (registered here,
    // next to its read-only counterpart, though it's consumed by `_registerAnalysis`).
    ..registerFactory<SyncDailyUsage>(() => SyncDailyUsage(getIt()))
    // Likewise replaced when F09 builds the `reminders` table.
    ..registerLazySingleton<UpcomingReminderRepository>(
      StubUpcomingReminderRepository.new,
    )
    ..registerFactory<WatchRecentDocuments>(() => WatchRecentDocuments(getIt()))
    ..registerFactory<WatchUpcomingReminder>(
      () => WatchUpcomingReminder(getIt()),
    )
    ..registerFactory<HomeCubit>(
      () => HomeCubit(
        watchDailyUsage: getIt(),
        watchRecentDocuments: getIt(),
        watchUpcomingReminder: getIt(),
      ),
    );
}

void _registerCapture() {
  getIt
    ..registerLazySingleton<PermissionService>(PermissionHandlerService.new)
    ..registerLazySingleton<CameraPermissionRepository>(
      () => SystemCameraPermissionRepository(getIt()),
    )
    ..registerFactory<GetCameraPermission>(() => GetCameraPermission(getIt()))
    ..registerFactory<RequestCameraPermission>(
      () => RequestCameraPermission(getIt()),
    )
    ..registerFactory<OpenPermissionSettings>(
      () => OpenPermissionSettings(getIt()),
    )
    ..registerFactory<CameraPermissionCubit>(
      () => CameraPermissionCubit(
        getCameraPermission: getIt(),
        requestCameraPermission: getIt(),
        openPermissionSettings: getIt(),
      ),
    )
    // One camera session per viewfinder: the service is created fresh for each
    // cubit so the live preview and the shutter share the exact same device
    // instance, and it is disposed when the route (and the cubit) is torn down.
    ..registerFactory<CameraCaptureCubit>(() {
      final camera = PlatformCameraService();
      return CameraCaptureCubit(
        preview: camera,
        initializeCamera: InitializeCamera(camera),
        capturePhoto: CapturePhoto(camera),
        disposeCamera: DisposeCamera(camera),
      );
    })
    ..registerLazySingleton<ImagePickerService>(SystemImagePickerService.new)
    ..registerFactory<PickImageFromGallery>(() => PickImageFromGallery(getIt()))
    ..registerFactory<GalleryPickerCubit>(
      () => GalleryPickerCubit(pickImageFromGallery: getIt()),
    )
    ..registerLazySingleton<ImageRotator>(ImagePackageRotator.new)
    ..registerFactory<RotateImage>(() => RotateImage(getIt()))
    ..registerLazySingleton<ImageQualityService>(DartImageQualityService.new)
    ..registerFactory<AssessImageQuality>(() => AssessImageQuality(getIt()))
    ..registerFactory<CreateAnalysisSession>(
      () => CreateAnalysisSession(getIt()),
    )
    ..registerLazySingleton<CaptureFileCleanup>(IOCaptureFileCleanup.new)
    ..registerFactory<CleanupCaptureFiles>(() => CleanupCaptureFiles(getIt()))
    ..registerLazySingleton<ConnectivityService>(ConnectivityPlusService.new)
    ..registerFactory<DecideAnalysisRoute>(
      () => DecideAnalysisRoute(getIt(), getIt()),
    )
    // `doclens`'s pure file operations only — never its camera UI (F13
    // locked decision #10).
    ..registerLazySingleton<PerspectiveCorrector>(
      DoclensPerspectiveCorrector.new,
    )
    ..registerFactory<CorrectPerspective>(() => CorrectPerspective(getIt()))
    // Parameterised by the acquired image's path — the cubit rotates,
    // assesses quality, and exports that specific file.
    ..registerFactoryParam<ImagePreviewCubit, String, void>(
      (path, _) => ImagePreviewCubit(
        source: CapturedPhoto(path),
        rotate: getIt(),
        assessQuality: getIt(),
        decideRoute: getIt(),
        correctPerspective: getIt(),
        createSession: getIt(),
        onlineHandoff: getIt(),
        ocrHandoff: getIt(),
        cleanupFiles: getIt(),
      ),
    );
}

void _registerOcr() {
  getIt
    ..registerLazySingleton<ImagePreprocessor>(DartImagePreprocessor.new)
    ..registerLazySingleton<OcrEngine>(TesseractOcrEngine.new)
    ..registerLazySingleton<OcrRepository>(
      () => DeviceOcrRepository(preprocessor: getIt(), engine: getIt()),
    )
    ..registerFactory<ExtractDocumentText>(() => ExtractDocumentText(getIt()))
    ..registerLazySingleton<TextNormalizer>(TextNormalizer.new)
    ..registerLazySingleton<DateExtractor>(DateExtractor.new)
    ..registerLazySingleton<TimeExtractor>(TimeExtractor.new)
    ..registerLazySingleton<AmountExtractor>(AmountExtractor.new)
    ..registerLazySingleton<PhoneExtractor>(PhoneExtractor.new)
    ..registerLazySingleton<ReferenceExtractor>(ReferenceExtractor.new)
    ..registerFactory<ExtractCandidates>(
      () => ExtractCandidates(
        normalizer: getIt(),
        dateExtractor: getIt(),
        timeExtractor: getIt(),
        amountExtractor: getIt(),
        phoneExtractor: getIt(),
        referenceExtractor: getIt(),
      ),
    )
    ..registerLazySingleton<OcrSessionHolder>(OcrSessionHolder.new)
    ..registerFactoryParam<OcrProcessingCubit, AnalysisSession, void>(
      (session, _) => OcrProcessingCubit(
        session: session,
        extractText: getIt(),
        extractCandidates: getIt(),
        sessionHolder: getIt(),
      ),
    );
}

/// Forces the bundled fixtures even in a configured build.
///
/// Kept so UI work (F07) does not require Docker and a Groq key on the desk:
/// `flutter run --flavor dev -t lib/main_dev.dart --dart-define=USE_MOCK_ANALYSIS=true`.
/// It cannot affect a release build — the mock is only reachable in dev.
const bool _useMockAnalysis = bool.fromEnvironment('USE_MOCK_ANALYSIS');

void _registerAnalysis(AppEnvironment env) {
  final useMock = env.isDev && _useMockAnalysis;

  getIt
    // F11-T02. Same `app_settings` table `DriftLocaleStore` reads/writes.
    ..registerLazySingleton<AnalysisConsentStore>(
      () => DriftAnalysisConsentStore(getIt()),
    )
    ..registerFactory<GetAnalysisConsent>(() => GetAnalysisConsent(getIt()))
    ..registerFactory<SetAnalysisConsent>(() => SetAnalysisConsent(getIt()))
    // F11-T03. Same `app_settings` table.
    ..registerLazySingleton<ProcessingModeStore>(
      () => DriftProcessingModeStore(getIt()),
    )
    ..registerFactory<GetProcessingMode>(() => GetProcessingMode(getIt()))
    ..registerFactory<SetProcessingMode>(() => SetProcessingMode(getIt()))
    // The real Edge Function client (F06-T14). An unconfigured build refuses
    // outright rather than falling back to fixtures: showing invented amounts
    // and deadlines to a real user would be worse than showing nothing, which
    // is the one thing this app must never do (§7).
    ..registerLazySingleton<AnalysisRemoteDataSource>(
      () => switch ((useMock, env.isConfigured)) {
        (true, _) => MockAnalysisRemoteDataSource(),
        (false, true) => EdgeFunctionAnalysisRemoteDataSource(getIt()),
        (false, false) => const DisabledAnalysisRemoteDataSource(),
      },
    )
    ..registerLazySingleton<AnalysisRepository>(
      () => DefaultAnalysisRepository(
        dataSource: getIt(),
        installationId: getIt(),
        logger: getIt(),
        appVersion: env.appVersion,
      ),
    )
    ..registerFactory<AnalyzeDocument>(() => AnalyzeDocument(getIt()))
    // Online-route counterpart (F13-T14), wired into the capture flow by
    // F13-T15's `ImageAnalysisSource`.
    ..registerFactory<AnalyzeImage>(() => AnalyzeImage(getIt()))
    // OCR-only half of the online route's two-call split (F14) — stops
    // before Groq so the user can review the text first.
    ..registerFactory<OcrImage>(() => OcrImage(getIt()))
    ..registerFactory<BuildAnalysisResult>(BuildAnalysisResult.new)
    // The online route's handoff (F13-T15) — the counterpart of
    // `OcrSessionHolder`, registered with F04's OCR feature below.
    ..registerLazySingleton<ImageAnalysisSessionHolder>(
      ImageAnalysisSessionHolder.new,
    )
    ..registerFactoryParam<
      AnalysisResultCubit,
      AnalysisSession,
      AnalysisSource
    >(
      (session, source) => AnalysisResultCubit(
        session: session,
        source: source,
        getAnalysisConsent: getIt(),
        analyzeDocument: getIt(),
        analyzeImage: getIt(),
        buildResult: getIt(),
        syncDailyUsage: getIt(),
        // On the online route the perspective-corrected file must survive
        // until the repository has read its bytes — the preview cubit's
        // close() skips it, so *this* callback takes ownership of deleting
        // it after the analysis reads (or fails to read) the file.
        onImageConsumed: source is ImageAnalysisSource
            ? getIt<ImageAnalysisSessionHolder>().clear
            : null,
      ),
    )
    // The OCR review screen (F14) — reuses `ExtractCandidates`, already
    // registered by `_registerOcr`, to re-extract candidates from the user's
    // approved text before it reaches Groq.
    ..registerFactoryParam<OcrReviewCubit, AnalysisSession, CapturedPhoto>(
      (session, photo) => OcrReviewCubit(
        session: session,
        photo: photo,
        ocrImage: getIt(),
        extractCandidates: getIt(),
        getAnalysisConsent: getIt(),
        imageHolder: getIt<ImageAnalysisSessionHolder>(),
      ),
    );
}

void _registerSavedPapers() {
  getIt
    ..registerLazySingleton<DocumentsDao>(
      () => getIt<AppDatabase>().documentsDao,
    )
    ..registerLazySingleton<DocumentEncryptionKeyStore>(
      () => DocumentEncryptionKeyStore(getIt()),
    )
    ..registerLazySingleton<FileEncryptor>(() => AesGcmFileEncryptor(getIt()))
    ..registerLazySingleton<DocumentImageStore>(
      () => FileDocumentImageStore(getIt()),
    )
    // Registered under its concrete type so `_registerHome` can alias
    // [RecentDocumentsRepository] to the same instance (F08-T05) — one
    // Drift-backed object answers both ports.
    ..registerLazySingleton<DriftDocumentsRepository>(
      () => DriftDocumentsRepository(
        getIt(),
        getIt(),
        reminderScheduler: getIt(),
      ),
    )
    ..registerLazySingleton<DocumentsRepository>(
      getIt.call<DriftDocumentsRepository>,
    )
    ..registerFactory<SaveDocument>(() => SaveDocument(getIt()))
    ..registerFactory<SaveDocumentWithImage>(
      () => SaveDocumentWithImage(getIt()),
    )
    ..registerFactory<CleanupAnalysisSession>(
      () => CleanupAnalysisSession(getIt()),
    )
    // Parameterised by the analysis session (F12-T06): it owns the last
    // possible read of that session's processed photo, so it needs the id
    // to clean up the session's leftover temp files once it's done with it.
    ..registerFactoryParam<SaveDocumentCubit, AnalysisSession, void>(
      (session, _) => SaveDocumentCubit(
        getIt(),
        getIt(),
        sessionId: session.id,
        cleanupSession: getIt(),
      ),
    )
    ..registerFactory<WatchDocuments>(() => WatchDocuments(getIt()))
    ..registerFactory<DocumentsListCubit>(() => DocumentsListCubit(getIt()))
    ..registerFactory<WatchDocument>(() => WatchDocument(getIt()))
    ..registerFactory<SetDocumentNote>(() => SetDocumentNote(getIt()))
    ..registerFactory<UpdateDocument>(() => UpdateDocument(getIt()))
    ..registerFactory<DeleteDocument>(() => DeleteDocument(getIt()))
    // F11-T11.
    ..registerFactory<DeleteAllDocuments>(() => DeleteAllDocuments(getIt()))
    // Parameterised by the document id — one cubit instance per opened
    // details screen, the same shape [ImagePreviewCubit]'s registration uses.
    ..registerFactoryParam<DocumentDetailsCubit, String, void>(
      (documentId, _) => DocumentDetailsCubit(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        documentId: documentId,
      ),
    );
}

void _registerReminders() {
  getIt
    ..registerLazySingleton<RemindersDao>(
      () => getIt<AppDatabase>().remindersDao,
    )
    ..registerLazySingleton<DriftRemindersRepository>(
      () => DriftRemindersRepository(getIt()),
    )
    ..registerLazySingleton<RemindersRepository>(
      getIt.call<DriftRemindersRepository>,
    )
    // F09-T10. `FlutterLocalNotificationsPort` is the only file allowed to
    // import `flutter_local_notifications`/`timezone` — everything above it,
    // including the scheduler, speaks `LocalNotificationsPort`.
    ..registerLazySingleton<fln.FlutterLocalNotificationsPlugin>(
      fln.FlutterLocalNotificationsPlugin.new,
    )
    ..registerLazySingleton<LocalNotificationsPort>(
      // Arabic, unconditionally — see `FlutterLocalNotificationsPort`'s own
      // doc comment for why this one string isn't locale-aware.
      () => FlutterLocalNotificationsPort(getIt(), 'التذكيرات'),
    )
    // F09-T14. Same `app_settings` table `DriftLocaleStore` reads/writes.
    ..registerLazySingleton<NotificationPrivacyStore>(
      () => DriftNotificationPrivacyStore(getIt()),
    )
    ..registerFactory<GetHideSensitiveNotificationDetails>(
      () => GetHideSensitiveNotificationDetails(getIt()),
    )
    ..registerFactory<SetHideSensitiveNotificationDetails>(
      () => SetHideSensitiveNotificationDetails(getIt()),
    )
    ..registerLazySingleton<ReminderScheduler>(
      () => LocalNotificationsReminderScheduler(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
      ),
    )
    ..registerFactory<CreateReminderFromDocumentDate>(
      () => CreateReminderFromDocumentDate(getIt(), getIt()),
    )
    ..registerFactory<CreateManualReminder>(
      () => CreateManualReminder(getIt(), getIt()),
    )
    ..registerFactory<CompleteReminder>(
      () => CompleteReminder(getIt(), getIt()),
    )
    ..registerFactory<SnoozeReminder>(() => SnoozeReminder(getIt(), getIt()))
    ..registerFactory<DeleteReminder>(() => DeleteReminder(getIt(), getIt()))
    // F11-T11.
    ..registerFactory<DeleteAllReminders>(
      () => DeleteAllReminders(getIt(), getIt()),
    )
    // F09-T09. Reuses the `PermissionService` singleton `_registerCapture`
    // already set up — one plugin boundary for every runtime permission.
    ..registerLazySingleton<NotificationPermissionRepository>(
      () => SystemNotificationPermissionRepository(getIt()),
    )
    ..registerFactory<GetNotificationPermission>(
      () => GetNotificationPermission(getIt()),
    )
    ..registerFactory<RequestNotificationPermission>(
      () => RequestNotificationPermission(getIt()),
    )
    // F11-T09. Settings re-opens the same notification permission the
    // reminder-save flow gates itself on.
    ..registerFactory<OpenNotificationPermissionSettings>(
      () => OpenNotificationPermissionSettings(getIt()),
    )
    // From a document's date (F09-T03): one cubit per opened form, seeded
    // with what the router already knows (the chosen date, and the document
    // it came from, if any).
    ..registerFactoryParam<ReminderFormCubit, ReminderFromDocumentArgs, void>(
      (args, _) => ReminderFormCubit.fromDocument(
        createFromDocumentDate: getIt(),
        createManual: getIt(),
        getNotificationPermission: getIt(),
        requestNotificationPermission: getIt(),
        args: args,
      ),
    )
    // Manual (F09-T04): a distinct registration under the same type, since
    // it starts from nothing rather than from router args — `instanceName`
    // is how get_it tells the two apart.
    ..registerFactory<ReminderFormCubit>(
      () => ReminderFormCubit.manual(
        createFromDocumentDate: getIt(),
        createManual: getIt(),
        getNotificationPermission: getIt(),
        requestNotificationPermission: getIt(),
      ),
      instanceName: manualReminderFormInstanceName,
    )
    // The reminders tab (F09-T11): a fresh cubit per visit, like every other
    // top-level list cubit here.
    ..registerFactory<WatchReminders>(() => WatchReminders(getIt()))
    ..registerFactory<WatchReminder>(() => WatchReminder(getIt()))
    ..registerFactory<RemindersCubit>(
      () => RemindersCubit(getIt(), getIt(), getIt()),
    )
    // One cubit per opened details screen, parameterised by the reminder's
    // id — the same shape `DocumentDetailsCubit` uses.
    ..registerFactory<ReminderDetailsCubit>(
      () => ReminderDetailsCubit(getIt(), getIt(), getIt(), getIt(), getIt()),
    );
}

void _registerAudioReader() {
  // F10-T01. `FlutterTtsTextToSpeechService` is the only file allowed to
  // import `flutter_tts` — everything above it speaks `TextToSpeechService`,
  // the same boundary `TesseractOcrEngine` keeps for its own plugin. One
  // instance app-wide: the OS TTS engine is itself a single shared resource.
  getIt
    ..registerLazySingleton<TextToSpeechService>(
      FlutterTtsTextToSpeechService.new,
    )
    // F10-T02. Stateless and total — a factory, like `BuildAnalysisResult`.
    ..registerFactory<BuildReadingText>(BuildReadingText.new)
    // F10-T07. Stateless and total, the same shape as `BuildReadingText`.
    ..registerFactory<SelectVoiceForReading>(SelectVoiceForReading.new)
    // F10-T04.
    ..registerFactory<StartReading>(
      () => StartReading(getIt(), getIt(), getIt()),
    )
    ..registerFactory<StopReading>(() => StopReading(getIt()))
    // F10-T05.
    ..registerFactory<PauseReading>(() => PauseReading(getIt()))
    ..registerFactory<ResumeReading>(() => ResumeReading(getIt()))
    // F10-T06.
    ..registerFactory<SetReadingSpeed>(() => SetReadingSpeed(getIt()))
    // F10-T08.
    ..registerFactory<WatchReadingEvents>(() => WatchReadingEvents(getIt()))
    // F11-T07. Same `app_settings` table `DriftLocaleStore` reads/writes.
    ..registerLazySingleton<DefaultReadingSpeedStore>(
      () => DriftDefaultReadingSpeedStore(getIt()),
    )
    ..registerFactory<GetDefaultReadingSpeed>(
      () => GetDefaultReadingSpeed(getIt()),
    )
    ..registerFactory<SetDefaultReadingSpeed>(
      () => SetDefaultReadingSpeed(getIt()),
    )
    ..registerLazySingleton<DefaultReadingVoiceStore>(
      () => DriftDefaultReadingVoiceStore(getIt()),
    )
    ..registerFactory<GetDefaultReadingVoice>(
      () => GetDefaultReadingVoice(getIt()),
    )
    ..registerFactory<SetDefaultReadingVoice>(
      () => SetDefaultReadingVoice(getIt()),
    )
    ..registerLazySingleton<ResumeReadingEnabledStore>(
      () => DriftResumeReadingEnabledStore(getIt()),
    )
    ..registerFactory<GetResumeReadingEnabled>(
      () => GetResumeReadingEnabled(getIt()),
    )
    ..registerFactory<SetResumeReadingEnabled>(
      () => SetResumeReadingEnabled(getIt()),
    )
    ..registerFactory<GetAvailableVoices>(() => GetAvailableVoices(getIt()))
    ..registerFactory<PreviewDefaultVoice>(
      () => PreviewDefaultVoice(getIt(), getIt()),
    )
    // One per result screen visit, like `AnalysisResultCubit` and
    // `SaveDocumentCubit` beside it.
    ..registerFactory<AudioReaderCubit>(
      () => AudioReaderCubit(
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
      ),
    );
}

void _registerSettings() {
  // F11-T02/T03. Reuses the store/use cases `_registerAnalysis` already
  // registered — Settings reads and writes the same consent and processing-
  // mode flags the analysis flow gates itself on.
  // F11-T07. Reuses the store/use cases `_registerAudioReader` already
  // registered — Settings reads and writes the same audio defaults the
  // mini-player applies to a fresh reading.
  // F11-T08. Reuses `GetCameraPermission`/`OpenPermissionSettings`
  // `_registerCapture` already registered — Settings reads and re-opens the
  // same camera permission the capture flow gates itself on.
  // F11-T09. Reuses `GetNotificationPermission`/`OpenNotificationPermissionSettings`
  // `_registerReminders` already registered — same reasoning, for
  // notifications.
  // F11-T10. Reuses `GetHideSensitiveNotificationDetails`/
  // `SetHideSensitiveNotificationDetails` `_registerReminders` already
  // registered (F09-T14) — Settings is their first UI.
  // F11-T11. `AppSettingsRepository`/`DeleteAllAppData` are new here;
  // `DeleteAllDocuments`/`DeleteAllReminders` reuse what `_registerSavedPapers`
  // and `_registerReminders` already registered.
  // F11-T12. Reuses `GetDailyUsage` `_registerLaunch` already registered
  // (next to `WatchDailyUsage`). `GetAppVersion` is new here, over the same
  // `AppEnvironment` singleton `_registerCore` registered.
  getIt
    ..registerLazySingleton<AppSettingsRepository>(
      () => DriftAppSettingsRepository(getIt()),
    )
    ..registerFactory<DeleteAllAppData>(
      () => DeleteAllAppData(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory<GetAppVersion>(() => GetAppVersion(getIt()))
    ..registerFactory<SettingsCubit>(
      () => SettingsCubit(
        getAnalysisConsent: getIt(),
        setAnalysisConsent: getIt(),
        getProcessingMode: getIt(),
        setProcessingMode: getIt(),
        getDefaultReadingSpeed: getIt(),
        setDefaultReadingSpeed: getIt(),
        getDefaultReadingVoice: getIt(),
        getResumeReadingEnabled: getIt(),
        setResumeReadingEnabled: getIt(),
        previewDefaultVoice: getIt(),
        getCameraPermission: getIt(),
        openPermissionSettings: getIt(),
        getNotificationPermission: getIt(),
        openNotificationSettings: getIt(),
        getHideSensitiveNotificationDetails: getIt(),
        setHideSensitiveNotificationDetails: getIt(),
        deleteAllDocuments: getIt(),
        deleteAllReminders: getIt(),
        getDailyUsage: getIt(),
        getAppVersion: getIt(),
        deleteAllAppData: getIt(),
      ),
    );
}

void _registerRouting() {
  getIt.registerLazySingleton<GoRouter>(
    () => createAppRouter(onboardingGate: getIt()),
  );
}
