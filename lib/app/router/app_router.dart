import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/storage/analysis_session.dart';
import '../../features/analysis/presentation/cubit/analysis_result_cubit.dart';
import '../../features/analysis/presentation/screens/analysis_result_screen.dart';
import '../../features/capture/domain/entities/capture_source.dart';
import '../../features/capture/presentation/cubit/camera_capture_cubit.dart';
import '../../features/capture/presentation/cubit/camera_permission_cubit.dart';
import '../../features/capture/presentation/cubit/gallery_picker_cubit.dart';
import '../../features/capture/presentation/cubit/image_preview_cubit.dart';
import '../../features/capture/presentation/screens/camera_capture_screen.dart';
import '../../features/capture/presentation/screens/camera_permission_gate.dart';
import '../../features/capture/presentation/screens/gallery_picker_screen.dart';
import '../../features/capture/presentation/screens/image_preview_screen.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import '../../features/ocr/presentation/ocr_session_holder.dart';
import '../../features/ocr/presentation/screens/ocr_processing_screen.dart';
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
  static const String preview = '/preview';
  static const String ocr = '/ocr';
  static const String result = '/result';

  /// The first-run flow, which sits outside the bottom-nav shell.
  static const Set<String> firstRun = {onboarding, privacy};

  /// The capture route for [source].
  ///
  /// The choice rides in the query string rather than in `extra`, so the
  /// location stays a plain restorable path — `extra` is dropped when the OS
  /// kills and restores the app mid-scan.
  static String captureWith(CaptureSource source) =>
      '$capture?source=${source.name}';

  /// The crop/rotate preview for the acquired image at [imagePath].
  ///
  /// The path rides in the query string for the same reason [captureWith] does
  /// — a plain restorable location rather than a dropped `extra`.
  static String previewWith(String imagePath) =>
      '$preview?path=${Uri.encodeQueryComponent(imagePath)}';
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
        builder: (context, state) => _captureEntry(
          context,
          CaptureSource.parse(state.uri.queryParameters['source']),
        ),
      ),
      // Pushed on top of the capture route: retake pops back to the camera or
      // picker; confirm leaves the flow. Full-screen, outside the shell.
      GoRoute(
        path: AppRoutes.preview,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          return BlocProvider<ImagePreviewCubit>(
            create: (_) => getIt<ImagePreviewCubit>(param1: path),
            child: ImagePreviewScreen(
              imagePath: path,
              onSessionCreated: (session) =>
                  context.pushReplacement(AppRoutes.ocr, extra: session),
              onRetake: context.pop,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.ocr,
        builder: (context, state) {
          final session = state.extra as AnalysisSession?;
          if (session == null) return const _BackToHome();
          return BlocProvider<OcrProcessingCubit>(
            create: (_) =>
                getIt<OcrProcessingCubit>(param1: session)..process(),
            // The builder's own `context` sits *above* this provider, so a
            // `read` on it cannot find the cubit. This [Builder] puts the
            // callbacks' context below it — without one, continuing threw
            // `ProviderNotFoundException` and the button did nothing.
            child: Builder(
              builder: (context) => OcrProcessingScreen(
                // Replaces this route: once the text is on its way to be
                // analysed there is no going back to the OCR view of it.
                onContinue: () {
                  context.read<OcrProcessingCubit>().confirm();
                  context.pushReplacement(AppRoutes.result);
                },
                onRetake: () => context.pushReplacement(
                  AppRoutes.captureWith(CaptureSource.camera),
                ),
                onPickAnother: () => context.pushReplacement(
                  AppRoutes.captureWith(CaptureSource.gallery),
                ),
              ),
            ),
          );
        },
      ),
      // Also outside the shell: the result belongs to the scan the user just
      // finished, and it is left through its own back control.
      GoRoute(
        path: AppRoutes.result,
        builder: (context, state) {
          // The OCR output is picked up from the hand-off holder rather than
          // from `extra`, which the OS drops when it kills and restores the
          // app — and OCR text is too expensive to redo silently.
          final handoff = getIt<OcrSessionHolder>();
          final session = handoff.session;
          final extraction = handoff.result;
          if (session == null || extraction == null) {
            return const _BackToHome();
          }
          return BlocProvider<AnalysisResultCubit>(
            create: (_) =>
                getIt<AnalysisResultCubit>(param1: session, param2: extraction)
                  ..analyze(),
            child: AnalysisResultScreen(
              onClose: () => context.go(AppRoutes.home),
              // Replaces this route: the paper that could not be explained is
              // not somewhere to come back to.
              onCaptureAnother: () => context.pushReplacement(
                AppRoutes.captureWith(CaptureSource.camera),
              ),
            ),
          );
        },
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

/// The entry point of the capture flow, for the source the user chose.
///
/// The camera goes through the permission gate first; the gallery does not
/// need one — the system photo picker asks for nothing (F03-T03).
Widget _captureEntry(BuildContext context, CaptureSource source) {
  return switch (source) {
    CaptureSource.camera => BlocProvider<CameraPermissionCubit>(
      create: (_) => getIt<CameraPermissionCubit>(),
      child: CameraPermissionGate(
        granted: _cameraViewfinder,
        // Replaces the camera route rather than stacking on it: the user chose
        // the gallery *instead*, so backing out should return to Home, not to
        // the permission sheet they just declined.
        onPickInstead: () => context.pushReplacement(
          AppRoutes.captureWith(CaptureSource.gallery),
        ),
        onDismiss: context.pop,
      ),
    ),
    CaptureSource.gallery => _galleryPicker(context),
  };
}

/// The camera viewfinder, once permission is granted.
///
/// A fresh [CameraCaptureCubit] per entry owns one camera session and releases
/// it when this route is popped. The captured photo hand-off is a placeholder
/// until F03-T06 builds the review screen — for now it returns to Home.
Widget _cameraViewfinder(BuildContext context) {
  return BlocProvider<CameraCaptureCubit>(
    create: (_) => getIt<CameraCaptureCubit>(),
    child: CameraCaptureScreen(
      onCaptured: (photo) => context.push(AppRoutes.previewWith(photo.path)),
      onClose: context.pop,
    ),
  );
}

/// The system photo picker flow.
///
/// The chosen photo hand-off is a placeholder until F03-T06 builds the review
/// screen — for now both a pick and a cancel return to Home.
Widget _galleryPicker(BuildContext context) {
  return BlocProvider<GalleryPickerCubit>(
    create: (_) => getIt<GalleryPickerCubit>(),
    child: GalleryPickerScreen(
      onPicked: (photo) => context.push(AppRoutes.previewWith(photo.path)),
      onCancelled: context.pop,
    ),
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

/// Sends the user back to Home, one frame after this builds.
///
/// The scan routes carry their subject with them — a session, an OCR result —
/// and reaching one without it means the flow was restored or deep-linked into
/// halfway through. There is nothing to show, so the route bounces instead of
/// rendering an empty screen.
class _BackToHome extends StatelessWidget {
  const _BackToHome();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(AppRoutes.home);
    });
    return const SizedBox.shrink();
  }
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
