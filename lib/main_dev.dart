import 'bootstrap.dart';
import 'core/env/app_environment.dart';

/// Entrypoint for the `dev` flavor.
///
/// Run with: `flutter run --flavor dev -t lib/main_dev.dart`
///
/// Points at the local Supabase stack (`supabase start` + `functions serve`) —
/// `10.0.2.2` on an Android emulator, `127.0.0.1` on an iOS simulator. Override
/// with `--dart-define=SUPABASE_URL=...` to reach the dev machine over the LAN
/// from a physical device.
void main() {
  bootstrap(AppEnvironment.dev());
}
