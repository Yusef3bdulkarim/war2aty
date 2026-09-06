import 'bootstrap.dart';
import 'core/env/app_environment.dart';

/// Entrypoint for the `prod` flavor.
///
/// Run with:
/// ```
/// flutter run --flavor prod -t lib/main_prod.dart \
///   --dart-define-from-file=config/prod.json
/// ```
///
/// Both values come from the build rather than a default in the source, so a
/// build that forgot them launches, reports itself unconfigured, and refuses
/// analyses with the normal maintenance copy — safer than shipping a
/// placeholder URL that fails in some less legible way.
void main() {
  bootstrap(AppEnvironment.prod());
}
