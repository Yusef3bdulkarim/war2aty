import 'bootstrap.dart';
import 'core/env/app_environment.dart';

/// Entrypoint for the `dev` flavor.
/// Run with: `flutter run --flavor dev -t lib/main_dev.dart`
void main() {
  const env = AppEnvironment(
    flavor: Flavor.dev,
    // Placeholder values — real Supabase config is wired in a later milestone.
    supabaseUrl: 'https://dev.placeholder.supabase.co',
    supabaseAnonKey: 'dev-placeholder-anon-key',
  );
  bootstrap(env);
}
