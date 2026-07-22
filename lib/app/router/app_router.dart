import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/capture/domain/entities/capture_source.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/onboarding/presentation/cubit/onboarding_state.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/privacy_screen.dart';
import '../di/service_locator.dart';
import '../shell/placeholder_tab.dart';
import '../shell/scaffold_with_nav_bar.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String privacy = '/privacy';
  static const String home = '/home';
  static const String saved = '/saved';
  static const String reminders = '/reminders';
  static const String settings = '/settings';
  static const String capture = '/capture';

  /// The first-run flow, which sits outside the bottom-nav shell.
  static const Set<String> firstRun = {onboarding, privacy};

  /// The capture route for [source].
  ///
  /// The choice rides in the query string rather than in `extra`, so the
  /// location stays a plain restorable path — `extra` is dropped when the OS
  /// kills and restores the app mid-scan.
  static String captureWith(CaptureSource source) =>
      '$capture?source=${source.name}';
}

/// Builds the app's [GoRouter]: the first-run flow, then a persistent
/// 4-destination bottom-nav shell.
///
/// [onboardingGate] drives the first-run redirect. It is app-scoped, and the
/// router re-evaluates the redirect whenever its state changes — so finishing
/// the privacy step navigates to Home without any explicit `go` call.
GoRouter createAppRouter({required OnboardingCubit onboardingGate}) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _CubitListenable(onboardingGate.stream),
    redirect: (context, state) =>
        _firstRunRedirect(onboardingGate.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      // Deliberately outside the shell: scanning is a task the user finishes
      // and leaves, not a place to browse, so it takes the whole screen and
      // the bottom bar goes away for its duration.
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => _capturePlaceholder(
          context,
          CaptureSource.parse(state.uri.queryParameters['source']),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => BlocProvider<HomeCubit>(
                  create: (_) => getIt<HomeCubit>()..start(),
                  // Pushed, not switched to: the user comes back to Home when
                  // the scan is done or cancelled, and Home keeps its scroll
                  // position and its live streams while they are away.
                  child: HomeScreen(
                    onScan: () => context.push(
                      AppRoutes.captureWith(CaptureSource.camera),
                    ),
                    onPickImage: () => context.push(
                      AppRoutes.captureWith(CaptureSource.gallery),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _branch(
            AppRoutes.saved,
            (c) => c.strings.navDocuments,
            Icons.bookmark,
          ),
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

/// Keeps the first-run flow and the shell mutually exclusive.
///
/// Returning `null` means "stay here". An unresolved gate is treated like a
/// first run: the app only builds the router once the flag is known, so that
/// branch is a safety net rather than a state the user can reach.
String? _firstRunRedirect(OnboardingState gate, String location) {
  final inFirstRun = AppRoutes.firstRun.contains(location);
  return switch (gate) {
    OnboardingUnknown() ||
    OnboardingRequired() => inFirstRun ? null : AppRoutes.onboarding,
    OnboardingCompleted() => inFirstRun ? AppRoutes.home : null,
  };
}

/// Stands in for F03's capture flow.
///
/// Home's two actions have to lead somewhere real for the entry point to work
/// and be testable, so this names the source the user picked and offers the
/// way back. F03 replaces it with the camera and the system picker.
Widget _capturePlaceholder(BuildContext context, CaptureSource source) {
  final s = context.strings;
  return switch (source) {
    CaptureSource.camera => PlaceholderTab(
      title: s.homeScanTitle,
      icon: Icons.photo_camera,
    ),
    CaptureSource.gallery => PlaceholderTab(
      title: s.homePickImage,
      icon: Icons.photo_library,
    ),
  };
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

/// Adapts a Cubit's [Stream] to the [Listenable] `GoRouter` expects, so gate
/// changes re-run the redirect.
final class _CubitListenable extends ChangeNotifier {
  _CubitListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
