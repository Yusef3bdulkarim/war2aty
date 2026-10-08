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

/// The mark the launch screen draws, cut by
/// `tool/branding/generate_brand_assets.dart` along with every other brand
/// asset.
///
/// At each density this file is **byte-identical** to the `splash_mark.png` the
/// native splash draws, because both come from the same source through the same
/// resize: `assets/images/brand_mark.png` is `drawable-mdpi/splash_mark.png`,
/// the 2.0x is xhdpi, the 3.0x is xxhdpi. `native_splash_test` asserts it.
const String kBrandMarkAsset = 'assets/images/brand_mark.png';

/// Side of the mark, in logical pixels.
///
/// The fourth place this number has to appear, and the reason it is a named
/// constant in all four: `_splashMarkDp` in the generator cuts the bitmaps,
/// `splash_icon.xml` pins the Android 12+ icon inside its 288 dp canvas, the
/// pre-12 bitmap is drawn at its intrinsic size, and this draws the Flutter
/// copy. A mismatch in any one of them is a mark that changes size at the
/// handover.
const double kSplashMarkSize = 128;

/// What the app shows while it is starting up, and instead of starting up if a
/// critical step fails.
///
/// The launch frame is the background colour and the mark, and nothing else —
/// no gradient, no glow, no pattern, no text (F28 decision 1, the owner's call
/// on 2026-10-08 after three patterned concepts were discarded).
///
/// **Nothing on it moves, and that is the design rather than an omission.**
/// The system splash has already drawn this exact frame by ~100 ms, and F28's
/// whole premise is that the swap to Flutter at ~440 ms is invisible. Anything
/// that faded or scaled the mark here would be a change the user could see at
/// precisely the moment there is meant to be nothing to notice — the old
/// splash's entrance was itself most of the ~775 ms wait that F27-T18 measured.
/// Reduced motion therefore needs no separate path: there is no motion to
/// reduce.
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
        // `SizedBox.expand` is load-bearing: a `Stack` shrink-wraps to its
        // largest child under loose constraints, so without it the mark sits
        // in the top-left corner instead of the centre. It went unnoticed from
        // F28-T02 until T06, because until the mark arrived both children were
        // invisible 1x1 leaves and it made no difference where they were.
        //
        // Two sibling leaves rather than one wrapper around the other: a
        // `Semantics` with a label of its own, placed above the stage region,
        // absorbs it, and the stage stops being announced at all.
        body: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The mark, labelled with the app's name — the one thing on
              // screen, and the first thing a screen reader says.
              Semantics(
                label: context.strings.appName,
                image: true,
                child: const _BrandMark(),
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
      ),
    );
  }
}

/// The brand mark, at the size and place the native splash already drew it.
///
/// Its pixels say nothing a screen reader needs — the label around it carries
/// the app's name, and announcing the image as well would say it twice.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        kBrandMarkAsset,
        width: kSplashMarkSize,
        height: kSplashMarkSize,
      ),
    );
  }
}
