import 'bootstrap.dart';
import 'core/env/app_environment.dart';

/// Entrypoint for the `prod` flavor.
///
/// Run with:
/// ```
/// flutter run --flavor prod -t lib/main_prod.dart \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<publishable key>
/// ```
///
/// There is no hosted project yet, so both values must come from the build.
/// Without them the app still launches, reports itself unconfigured, and
/// refuses analyses with the normal maintenance copy — which is safer than
/// shipping a placeholder URL that fails in some less legible way.
void main() {
  bootstrap(AppEnvironment.prod());
}
