import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'core/env/app_environment.dart';

/// Shared launch path for every flavor entrypoint.
///
/// Initializes the framework, wires dependencies for the given [env], and boots
/// the app into its localized 4-tab shell.
Future<void> bootstrap(AppEnvironment env) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(env);
  runApp(const WaraqtiApp());
}
