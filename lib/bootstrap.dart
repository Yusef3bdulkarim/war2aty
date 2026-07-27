import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'core/env/app_environment.dart';

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
  if (resolved.isConfigured) {
    await Supabase.initialize(
      url: resolved.supabaseUrl,
      // `publishableKey`, not the deprecated `anonKey`. The SDK treats them
      // interchangeably; both names describe the one key §24 permits in the
      // client.
      publishableKey: resolved.supabaseAnonKey,
    );
  }

  await configureDependencies(resolved);
  runApp(const WaraqtiApp());
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
