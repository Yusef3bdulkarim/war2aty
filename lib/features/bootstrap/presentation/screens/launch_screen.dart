import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/bootstrap_stage.dart';
import '../cubit/bootstrap_cubit.dart';
import '../cubit/bootstrap_state.dart';
import 'launch_error_screen.dart';

/// The colour the native splash shows, and therefore the colour this screen's
/// first frame must be.
///
/// Single source of truth for all four places that have to agree: Android's
/// `@color/splash_bg` and `windowSplashScreenBackground`, the iOS storyboard's
/// background, and this screen. F28-T05 generates the first three from it; if
/// they drift, the handover from the native splash to Flutter becomes visible.
const Color kLaunchBackground = Color(0xFF0A6C76);

/// What the app shows while it is starting up, and instead of starting up if a
/// critical step fails.
///
/// **Interim (F28-T02).** The splash this replaces is gone and its successor is
/// not built yet, so the launch frame here is the flat native colour and
/// nothing else. F28-T06 fills it in with the approved design, which is why
/// the state switch lives here rather than inside whatever draws the splash:
/// handling a launch failure is this screen's job in every design, and drawing
/// a brand animation is the job of exactly one widget that T06 will add.
///
/// What is deliberately kept through the interim, because it is behaviour
/// rather than decoration: the app's name as the first thing a screen reader
/// announces, and the running launch stage as a live region.
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BootstrapCubit, BootstrapState>(
      builder: (context, state) => switch (state) {
        BootstrapFailure() => LaunchErrorScreen(
          onRetry: () => context.read<BootstrapCubit>().start(),
        ),
        BootstrapInitial() ||
        BootstrapInProgress() ||
        BootstrapSuccess() => _LaunchFrame(
          stage: state is BootstrapInProgress ? state.stage : null,
        ),
      },
    );
  }
}

class _LaunchFrame extends StatelessWidget {
  const _LaunchFrame({required this.stage});

  /// The launch step in flight, announced to screen readers; `null` before the
  /// first one.
  final BootstrapStage? stage;

  /// Localized description of the running stage, for screen readers.
  String? _stageLabel(BuildContext context) {
    final s = context.strings;
    return switch (stage) {
      null => null,
      BootstrapStage.session => s.bootstrapStageSession,
      BootstrapStage.config => s.bootstrapStageConfig,
      BootstrapStage.cleanup => s.bootstrapStageCleanup,
      BootstrapStage.reminders => s.bootstrapStageReminders,
      BootstrapStage.usage => s.bootstrapStageUsage,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons on the teal, until the app takes over.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kLaunchBackground,
        // Two sibling leaves rather than one wrapper around the other: a
        // `Semantics` with a label of its own, placed above the stage region,
        // absorbs it, and the stage stops being announced at all.
        body: Stack(
          alignment: Alignment.center,
          children: [
            // The app's name, the first thing a screen reader says. F28-T06
            // moves this label onto the mark it draws, which is where it sat
            // before the purge.
            Semantics(
              container: true,
              label: context.strings.appName,
              child: const SizedBox.square(dimension: 1),
            ),
            Semantics(
              container: true,
              liveRegion: true,
              label: _stageLabel(context),
              child: const SizedBox.square(dimension: 1),
            ),
          ],
        ),
      ),
    );
  }
}
