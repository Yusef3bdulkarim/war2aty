import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/shell/scaffold_with_nav_bar.dart';

/// Routes matching the app's four shell branches, for nav-bar tests.
const List<String> shellPaths = ['/home', '/saved', '/reminders', '/settings'];

/// Builds the real [ScaffoldWithNavBar] over a throwaway four-branch router,
/// starting on [currentIndex].
///
/// A [StatefulNavigationShell] can only be produced by `go_router` itself, so
/// the bar is exercised through a genuine shell route rather than a stand-in —
/// which also means these tests cover the real wiring, not a mock of it.
Widget shellHarness({int currentIndex = 0}) {
  final router = GoRouter(
    initialLocation: shellPaths[currentIndex],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          for (final path in shellPaths)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => Center(child: Text(path)),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  return _HarnessApp(router: router);
}

/// Hosts the router without a second [MaterialApp] wrapping it — `pumpApp`
/// already supplies theme and localizations above this widget.
class _HarnessApp extends StatelessWidget {
  const _HarnessApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => Router.withConfig(config: router);
}
