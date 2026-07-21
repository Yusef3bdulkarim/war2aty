import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/local_runtime_config_repository.dart';
import '../../core/config/runtime_config_repository.dart';
import '../../core/config/runtime_config_store.dart';
import '../../core/database/app_database.dart';
import '../../core/env/app_environment.dart';
import '../../core/identity/installation_id_provider.dart';
import '../../core/localization/locale_cubit.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/usecases/get_saved_locale.dart';
import '../../core/localization/usecases/set_locale.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_sink.dart';
import '../../core/reminders/reminder_scheduler.dart';
import '../../core/result/result.dart';
import '../../core/storage/analysis_session_storage.dart';
import '../../core/storage/flutter_secure_storage_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/usage/stub_usage_repository.dart';
import '../../core/usage/usage_repository.dart';
import '../../features/bootstrap/data/repositories/stub_auth_repository.dart';
import '../../features/bootstrap/domain/entities/bootstrap_stage.dart';
import '../../features/bootstrap/domain/repositories/auth_repository.dart';
import '../../features/bootstrap/domain/usecases/ensure_active_session.dart';
import '../../features/bootstrap/domain/usecases/initialize_app.dart';
import '../../features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
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
  _registerIdentity();
  _registerLaunch();
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

void _registerIdentity() {
  getIt
    ..registerLazySingleton<SecureStorageService>(
      FlutterSecureStorageService.new,
    )
    ..registerLazySingleton<InstallationIdProvider>(
      () => SecureInstallationIdProvider(getIt()),
    )
    // Stub until real Supabase Anonymous Auth lands at M4.
    ..registerLazySingleton<AuthRepository>(
      () => StubAuthRepository(getIt(), getIt()),
    )
    ..registerFactory<EnsureActiveSession>(() => EnsureActiveSession(getIt()));
}

void _registerLaunch() {
  getIt
    ..registerLazySingleton<RuntimeConfigRepository>(
      () => LocalRuntimeConfigRepository(getIt()),
    )
    ..registerLazySingleton<AnalysisSessionStorage>(
      FileAnalysisSessionStorage.new,
    )
    // Replaced by the real scheduler when F09 lands.
    ..registerLazySingleton<ReminderScheduler>(NoopReminderScheduler.new)
    ..registerLazySingleton<UsageRepository>(
      () => StubUsageRepository(
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
        getIt<RuntimeConfigStore>().current = value;
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

void _registerRouting() {
  getIt.registerLazySingleton<GoRouter>(createAppRouter);
}
