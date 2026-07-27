import 'dart:io' show Platform;

/// Build flavor the app was launched with.
///
/// Only `dev` and `prod` exist in the MVP. A `staging` flavor is deferred
/// until closer to release (see master plan §56).
enum Flavor { dev, prod }

/// Immutable, per-flavor runtime configuration.
///
/// Constructed by the flavor entrypoint (`main_dev.dart` / `main_prod.dart`)
/// and passed into [bootstrap]. Holds only values that are safe to ship inside
/// the app — the Supabase *publishable* key is allowed here; the service-role
/// key and the AI provider key never are (§24).
final class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.appVersion = fallbackAppVersion,
  });

  /// The `dev` flavor, pointed at the local Docker stack (F06-T01).
  ///
  /// [isAndroid] decides the host, because "localhost" means a different
  /// machine on each platform — see [localStackUrl]. It is a parameter rather
  /// than a direct `Platform` read so the choice stays testable on any host.
  ///
  /// Both values can be overridden at build time, which is how a physical
  /// device is pointed at the dev machine on the same LAN:
  ///
  /// ```
  /// flutter run --flavor dev -t lib/main_dev.dart \
  ///   --dart-define=SUPABASE_URL=http://192.168.1.5:54321
  /// ```
  factory AppEnvironment.dev({bool? isAndroid, String? appVersion}) {
    return AppEnvironment(
      flavor: Flavor.dev,
      supabaseUrl: _dartDefineUrl.isNotEmpty
          ? _dartDefineUrl
          : localStackUrl(isAndroid ?? Platform.isAndroid),
      supabaseAnonKey: _dartDefineAnonKey.isNotEmpty
          ? _dartDefineAnonKey
          : localStackAnonKey,
      appVersion: appVersion ?? fallbackAppVersion,
    );
  }

  /// The `prod` flavor. Both values must be supplied at build time — there is
  /// no hosted project yet, and a placeholder URL that silently "works" would
  /// be worse than a build that reports itself unconfigured.
  factory AppEnvironment.prod({String? appVersion}) {
    return AppEnvironment(
      flavor: Flavor.prod,
      supabaseUrl: _dartDefineUrl,
      supabaseAnonKey: _dartDefineAnonKey,
      appVersion: appVersion ?? fallbackAppVersion,
    );
  }

  final Flavor flavor;

  /// Semantic version sent as `app_version` so the backend can gate builds
  /// below `minimumAppVersion` (API_CONTRACT §29/§31).
  ///
  /// Read from the platform bundle at launch (`package_info_plus`), per §29's
  /// field mapping. [fallbackAppVersion] applies only when the bundle cannot be
  /// read — a hardcoded constant would keep claiming `1.0.0` after a release
  /// bump, quietly disarming the server-side gate.
  final String appVersion;

  /// Supabase project URL for this flavor.
  final String supabaseUrl;

  /// Supabase publishable ("anon") key — safe to embed in the client (§24).
  final String supabaseAnonKey;

  /// Human-readable flavor name, e.g. `"dev"` / `"prod"`.
  String get name => flavor.name;

  bool get isDev => flavor == Flavor.dev;

  /// Whether this build has enough configuration to reach a backend.
  ///
  /// Only `prod` can be false, and only when the dart-defines were forgotten.
  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Base URL for the Edge Functions.
  String get functionsBaseUrl => '$supabaseUrl/functions/v1';

  /// Used only when the platform bundle cannot be read.
  static const String fallbackAppVersion = '1.0.0';

  static const String _dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _dartDefineAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Where the local stack lives, as seen from the device.
  ///
  /// On an Android emulator `127.0.0.1` is the *emulator itself*, not the
  /// developer's machine — `10.0.2.2` is the alias for the host loopback. The
  /// iOS simulator shares the host's network stack, so `127.0.0.1` is right
  /// there. Getting this backwards produces a connection-refused that looks
  /// exactly like a stack which is not running.
  static String localStackUrl(bool isAndroid) =>
      isAndroid ? 'http://10.0.2.2:54321' : 'http://127.0.0.1:54321';

  /// The anon key `supabase start` prints.
  ///
  /// Identical for every local project, published in Supabase's own docs, and
  /// useless against anything but a stack running on this machine. It is a
  /// publishable key, which §24 explicitly permits in the client; the usage
  /// tables stay unreachable with it (RLS on, zero policies — §26).
  static const String localStackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
      '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
}
