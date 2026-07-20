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
/// key and the Groq key never are.
final class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final Flavor flavor;

  /// Supabase project URL for this flavor.
  final String supabaseUrl;

  /// Supabase publishable ("anon") key — safe to embed in the client.
  final String supabaseAnonKey;

  /// Human-readable flavor name, e.g. `"dev"` / `"prod"`.
  String get name => flavor.name;

  bool get isDev => flavor == Flavor.dev;
}
