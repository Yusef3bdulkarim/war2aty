import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'core/env/app_environment.dart';
import 'core/logging/global_error_handlers.dart';
import 'core/storage/flutter_secure_storage_service.dart';
import 'core/storage/secure_session_local_storage.dart';

/// Shared launch path for every flavor entrypoint.
///
/// Initializes the framework and the Supabase client, wires dependencies for
/// the given [env], and boots the app into its localized 4-tab shell.
///
/// Supabase is initialized here rather than inside DI because it is process
/// global: `Supabase.instance` must exist before anything resolves an
/// `AuthRepository`, and initializing it twice throws.
Future<void> bootstrap(AppEnvironment env) async {
  WidgetsFlutterBinding.ensureInitialized();

  final resolved = AppEnvironment(
    flavor: env.flavor,
    supabaseUrl: env.supabaseUrl,
    supabaseAnonKey: env.supabaseAnonKey,
    appVersion: await _readAppVersion(env),
  );

  // An unconfigured build (prod without its dart-defines) still launches: DI
  // falls back to the datasource that refuses every analysis, so the user gets
  // the normal «الخدمة غير متاحة» copy instead of a crash on a black screen.
  final launchEnv = resolved.isConfigured
      ? await _initializeSupabase(resolved)
      : resolved;

  await configureDependencies(launchEnv);

  // After DI, because it needs the logger; before `runApp`, so the first frame
  // is already covered (F27-T12).
  installGlobalErrorHandlers(getIt());

  runApp(const WaraqtiApp());
}

/// Starts the Supabase client, degrading rather than dying if it cannot.
///
/// Everything here runs BEFORE `runApp`, so a throw or a hang leaves the native
/// launch screen up forever — no Flutter frame, no error, nothing to retry.
/// That is the worst failure mode the app has, and it is worth trading for a
/// degraded launch: returning an unconfigured environment makes DI register the
/// stub identity and the datasource that refuses analyses, so the user reaches
/// a working app that says the service is unavailable.
Future<AppEnvironment> _initializeSupabase(AppEnvironment env) async {
  try {
    await Supabase.initialize(
      url: env.supabaseUrl,
      // `publishableKey`, not the deprecated `anonKey`. The SDK treats them
      // interchangeably; both names describe the one key §24 permits in the
      // client.
      publishableKey: env.supabaseAnonKey,
      // F27-T16: without this the SDK installs `SharedPreferencesLocalStorage`
      // and the session — access JWT and long-lived refresh token — is written
      // to plain `SharedPreferences`, while `SecureStorageKeys.session` claimed
      // it must stay encrypted. Constructed directly rather than resolved from
      // `get_it`, because this runs before `configureDependencies`.
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureSessionLocalStorage(FlutterSecureStorageService()),
      ),
    ).timeout(const Duration(seconds: 15));

    return env;
  } on Object {
    // Blank credentials ARE the representation of "unconfigured" — the same
    // state a prod build without its dart-defines launches in, so there is one
    // degraded path rather than two.
    return AppEnvironment(
      flavor: env.flavor,
      supabaseUrl: '',
      supabaseAnonKey: '',
      appVersion: env.appVersion,
    );
  }
}

/// The real bundle version, for the server-side version gate (§29 rule 2).
///
/// A failure to read it falls back to the compiled-in constant rather than
/// blocking launch: an unknown version costs one correct gate decision, but a
/// throw here would cost the whole app.
Future<String> _readAppVersion(AppEnvironment env) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version.isNotEmpty ? info.version : env.appVersion;
  } on Object {
    return env.appVersion;
  }
}

// F28-T02 removed `_precacheSplashMark`, which started decoding the splash mark
// here so it was in the image cache by the splash's first frame rather than
// being decoded during its animation. It referenced the deleted splash screen's
// asset constant. F28-T06 needs the same trick for whatever the new splash
// draws, and the native splash in F28-T05 removes most of the urgency: the mark
// is already on screen before Flutter starts.
