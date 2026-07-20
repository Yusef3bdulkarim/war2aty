import 'package:flutter/material.dart';

import 'core/env/app_environment.dart';

/// Shared launch path for every flavor entrypoint.
///
/// For F00-T02 this only renders a throwaway placeholder that proves the
/// `dev`/`prod` boot works. The real shell (theme, localization, router, DI)
/// is wired up across later F00 tasks and replaces this at T16.
Future<void> bootstrap(AppEnvironment env) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(_PlaceholderApp(env: env));
}

class _PlaceholderApp extends StatelessWidget {
  const _PlaceholderApp({required this.env});

  final AppEnvironment env;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'War2aty',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('War2aty — ${env.name}'))),
    );
  }
}
