import 'bootstrap.dart';
import 'core/env/app_environment.dart';

/// Entrypoint for the `prod` flavor.
/// Run with: `flutter run --flavor prod -t lib/main_prod.dart`
void main() {
  const env = AppEnvironment(
    flavor: Flavor.prod,
    // Placeholder values — real Supabase config is wired in a later milestone.
    supabaseUrl: 'https://prod.placeholder.supabase.co',
    supabaseAnonKey: 'prod-placeholder-anon-key',
  );
  bootstrap(env);
}
