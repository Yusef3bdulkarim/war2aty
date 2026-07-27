import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/local_runtime_config_repository.dart';
import '../../core/config/runtime_config_repository.dart';
import '../../core/config/runtime_config_store.dart';
import '../../core/database/app_database.dart';
import '../../core/documents/recent_documents_repository.dart';
import '../../core/documents/stub_recent_documents_repository.dart';
import '../../core/documents/usecases/watch_recent_documents.dart';
import '../../core/env/app_environment.dart';
import '../../core/identity/installation_id_provider.dart';
import '../../core/localization/locale_cubit.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/usecases/get_saved_locale.dart';
import '../../core/localization/usecases/set_locale.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_sink.dart';
import '../../core/network/api_client.dart';
import '../../core/permissions/permission_handler_service.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/reminders/reminder_scheduler.dart';
import '../../core/reminders/stub_upcoming_reminder_repository.dart';
import '../../core/reminders/upcoming_reminder_repository.dart';
import '../../core/reminders/usecases/watch_upcoming_reminder.dart';
import '../../core/result/result.dart';
import '../../core/storage/analysis_session.dart';
import '../../core/storage/analysis_session_storage.dart';
import '../../core/storage/flutter_secure_storage_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/usage/remote_usage_repository.dart';
import '../../core/usage/stub_usage_repository.dart';
import '../../core/usage/usage_remote_data_source.dart';
import '../../core/usage/usage_repository.dart';
import '../../core/usage/usecases/watch_daily_usage.dart';
import '../../features/analysis/data/datasources/analysis_remote_data_source.dart';
import '../../features/analysis/data/datasources/disabled_analysis_remote_data_source.dart';
import '../../features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';
import '../../features/analysis/data/datasources/mock_analysis_remote_data_source.dart';
import '../../features/analysis/data/repositories/default_analysis_repository.dart';
import '../../features/analysis/domain/repositories/analysis_repository.dart';
import '../../features/analysis/domain/usecases/analyze_document.dart';
import '../../features/bootstrap/data/repositories/stub_auth_repository.dart';
import '../../features/bootstrap/data/repositories/supabase_auth_repository.dart';
import '../../features/bootstrap/domain/entities/bootstrap_stage.dart';
import '../../features/bootstrap/domain/repositories/auth_repository.dart';
import '../../features/bootstrap/domain/usecases/ensure_active_session.dart';
import '../../features/bootstrap/domain/usecases/initialize_app.dart';
import '../../features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import '../../features/capture/data/repositories/system_camera_permission_repository.dart';
import '../../features/capture/data/services/dart_image_quality_service.dart';
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
import '../../features/capture/domain/usecases/assess_image_quality.dart';
import '../../features/capture/domain/usecases/capture_photo.dart';
import '../../features/capture/domain/usecases/cleanup_capture_files.dart';
import '../../features/capture/domain/usecases/create_analysis_session.dart';
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
  _registerIdentity(env);
  _registerNetwork(env);
  _registerLaunch(env);
  _registerOnboarding();
  _registerHome();
  _registerCapture();
  _registerOcr();
  _registerAnalysis(env);
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
    // Replaced by the real scheduler when F09 lands.
    ..registerLazySingleton<ReminderScheduler>(NoopReminderScheduler.new)
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
    // Replaced by the Drift-backed implementation when F08 builds the
    // `documents` table; Home does not change when that happens.
    ..registerLazySingleton<RecentDocumentsRepository>(
      StubRecentDocumentsRepository.new,
    )
    ..registerFactory<WatchDailyUsage>(() => WatchDailyUsage(getIt()))
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
    // Parameterised by the acquired image's path — the cubit rotates,
    // assesses quality, and exports that specific file.
    ..registerFactoryParam<ImagePreviewCubit, String, void>(
      (path, _) => ImagePreviewCubit(
        source: CapturedPhoto(path),
        rotate: getIt(),
        assessQuality: getIt(),
        createSession: getIt(),
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
    ..registerFactory<AnalyzeDocument>(() => AnalyzeDocument(getIt()));
}

void _registerRouting() {
  getIt.registerLazySingleton<GoRouter>(
    () => createAppRouter(onboardingGate: getIt()),
  );
}
