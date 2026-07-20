import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../shell/placeholder_tab.dart';
import '../shell/scaffold_with_nav_bar.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String home = '/home';
  static const String saved = '/saved';
  static const String reminders = '/reminders';
  static const String settings = '/settings';
}

/// Builds the app's [GoRouter] with a persistent 4-destination bottom-nav shell.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          _branch(AppRoutes.home, (c) => c.strings.navHome, Icons.home),
          _branch(AppRoutes.saved, (c) => c.strings.navSaved, Icons.bookmark),
          _branch(
            AppRoutes.reminders,
            (c) => c.strings.navReminders,
            Icons.notifications,
          ),
          _branch(
            AppRoutes.settings,
            (c) => c.strings.navSettings,
            Icons.settings,
          ),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(
  String path,
  String Function(BuildContext) title,
  IconData icon,
) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) =>
            PlaceholderTab(title: title(context), icon: icon),
      ),
    ],
  );
}
