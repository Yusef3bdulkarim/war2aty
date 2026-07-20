import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/env/app_environment.dart';
import '../../core/localization/locale_cubit.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/usecases/get_saved_locale.dart';
import '../../core/localization/usecases/set_locale.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_sink.dart';
import '../router/app_router.dart';

/// Global service locator.
final GetIt getIt = GetIt.instance;

/// Wires up all dependencies. Call once during [bootstrap], before `runApp`.
Future<void> configureDependencies(AppEnvironment env) async {
  _registerCore(env);
  _registerDatabase();
  _registerLocalization();
  _registerRouting();
}

void _registerCore(AppEnvironment env) {
  getIt
    ..registerSingleton<AppEnvironment>(env)
    // Logging is verbose in dev, silent in prod (privacy-first default).
    ..registerLazySingleton<LogSink>(
      () => env.isDev ? const DeveloperLogSink() : const NoopLogSink(),
    )
    ..registerLazySingleton<AppLogger>(() => StructuredAppLogger(getIt()));
}

void _registerDatabase() {
  getIt.registerSingleton<AppDatabase>(AppDatabase());
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

void _registerRouting() {
  getIt.registerLazySingleton<GoRouter>(createAppRouter);
}
