import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/bootstrap_stage.dart';
import '../cubit/bootstrap_cubit.dart';
import '../cubit/bootstrap_state.dart';
import '../splash_timing.dart';
import '../widgets/splash_hand_off.dart';

/// The brand mark the splash draws (F27-P01), generated with every other icon
/// by `tool/branding/generate_brand_assets.dart`.
const String kBrandMarkAsset = 'assets/images/brand_mark.png';

/// Side of the mark, in logical pixels.
const double kSplashMarkSize = 128;

/// Side of the soft glow behind it.
const double kSplashGlowSize = 436;

/// How long one breath of the resting mark takes.
const Duration kSplashBreathPeriod = Duration(milliseconds: 3200);

/// The two animated parts, so a test can pin them rather than guess which of
/// the tree's transitions is the splash's own.
@visibleForTesting
const Key kSplashGlowKey = Key('splash.glow');
@visibleForTesting
const Key kSplashMarkKey = Key('splash.mark');

/// Launch screen: brand splash while initializing, error state with retry if a
/// critical step fails.
///
/// The owner-approved design of F27-P01 (HTML preview
/// `tool/branding/splash_preview.html`, where it is option 3): the mark alone
/// at the centre of the brand gradient over a soft glow, breathing gently.
/// There is no text on screen; the app name and the launch stage are there for
/// screen readers only.
///
/// The gradient and the glow never change, so each sits under its own repaint
/// boundary; the only thing that moves is the mark, by opacity and scale.
///
/// That structure is deliberate but it is **not** what makes the launch
/// smooth, and the record should not imply it does. An earlier version orbited
/// painted rings around the mark; replacing them with this, and adding the
/// boundaries, left the frame timing on the test phone unchanged (F27-P01).
/// The few single frames a launch still misses come from the work going on
/// around it — the network, the database, the notification plugin — not from
/// what this screen draws.
///
/// The native splashes before it show the teal alone, so the mark appears once,
/// here. Entrance, in seconds of the 1.8 s [kLogoEntranceDuration]:
///   0.00 → 0.70  glow fades in
///   0.00 → 0.30  mark fades in, scaling 0.90 → 1.0 (F27-T18 D-2: this was
///                0.10 → 0.75, which on a phone read as a second of blank
///                teal before the mark arrived)
/// The mark then breathes for as long as the launch takes. Once it is done,
/// [SplashHandOff] stills it, builds the app under the motionless splash, and
/// only then fades it off.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BootstrapCubit, BootstrapState>(
      builder: (context, state) => switch (state) {
        BootstrapFailure() => _LaunchError(
          onRetry: () => context.read<BootstrapCubit>().start(),
        ),
        BootstrapInitial() ||
        BootstrapInProgress() ||
        BootstrapSuccess() => _AnimatedSplash(
          state: state,
          // The launch waits on this rather than on a timer of its own, so the
          // hand-off happens when the mark has actually finished, not when a
          // clock started before the first frame says it should have.
          onEntranceFinished: () =>
              context.read<BootstrapCubit>().splashEntranceFinished(),
        ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Animated splash
// ---------------------------------------------------------------------------

class _AnimatedSplash extends StatefulWidget {
  const _AnimatedSplash({
    required this.state,
    required this.onEntranceFinished,
  });

  final BootstrapState state;

  /// Fired once, when the entrance animation has played all the way out.
  final VoidCallback onEntranceFinished;

  @override
  State<_AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<_AnimatedSplash>
    with TickerProviderStateMixin {
  // ── Entrance (one-shot): the glow, then the mark ──
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: kLogoEntranceDuration,
  );

  // ── The resting breath, once the entrance has played ──
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: kSplashBreathPeriod,
  );

  // ── Derived entrance curves, in seconds of the entrance ──
  late final Animation<double> _glowIn = _span(0, 0.70);
  // F27-T18 finding D-2. This used to be `_span(0.10, 0.75)`, and on a real
  // phone that read as a second of blank teal: the native splash shows no mark,
  // the app's first frame lands at ~440 ms and is itself still mark-free, and
  // only then did a 650 ms fade start — so the mark was not solid until
  // ~1.2 s after the tap. Nothing was slow; the two deliberate choices simply
  // stacked. Bringing the fade forward removes most of the wait and keeps the
  // part that earns it: the entrance still starts two frames late, so the
  // first frame's cost lands on a still screen rather than jumping the mark.
  late final Animation<double> _markIn = _span(0, 0.30);
  late final Animation<double> _markScale = Tween<double>(
    begin: 0.90,
    end: 1,
  ).animate(_markIn);

  /// The entrance between [from] and [to] seconds, eased out.
  Animation<double> _span(double from, double to) {
    final total = kLogoEntranceDuration.inMicroseconds / 1e6;
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        (from / total).clamp(0, 1),
        (to / total).clamp(0, 1),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onEntranceFinished();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final phases = SplashPhases.of(context);
    if (phases.settle != _settle) {
      _settle.removeStatusListener(_onSettleStatus);
      _settle = phases.settle..addStatusListener(_onSettleStatus);
    }
    if (phases.exit != _exit) _exit = phases.exit;

    if (_started) return;
    _started = true;

    // Under reduced motion, show the settled frame at once and release the
    // launch immediately — the hold exists to protect the animation, so with no
    // animation to protect it would just be dead time. Nothing breathes either.
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _entrance.value = 1;
      widget.onEntranceFinished();
    } else {
      // This build is the app's very first frame — the costliest it will ever
      // have (~210 ms measured on a mid-range phone). Starting the animation
      // after it keeps that stall on a still, plain teal screen, the same as
      // the native splash before it, instead of a visible jump in the mark.
      _afterFrames(2, () {
        if (!mounted) return;
        _entrance.forward();
        _breath.repeat();
      });
    }
  }

  /// [then] once [frames] frames have been drawn, asking for each.
  static void _afterFrames(int frames, VoidCallback then) {
    SchedulerBinding.instance
      ..addPostFrameCallback(
        (_) => frames <= 1 ? then() : _afterFrames(frames - 1, then),
      )
      ..ensureVisualUpdate();
  }

  /// `didChangeDependencies` runs again whenever an ancestor changes; the
  /// entrance must only ever be kicked off once.
  bool _started = false;

  /// Reduced motion, read once with the entrance.
  bool _still = false;

  /// The hand-off's settle (see [SplashHandOff]): the breath fades out over it,
  /// so nothing moves while the app is built under the splash.
  Animation<double> _settle = kAlwaysDismissedAnimation;

  /// Once at rest, stop breathing: no more frames until the reveal.
  void _onSettleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _breath.stop();
  }

  /// The hand-off's reveal: the mark grows a little as the splash fades off.
  Animation<double> _exit = kAlwaysDismissedAnimation;

  @override
  void dispose() {
    _settle.removeStatusListener(_onSettleStatus);
    _breath.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// Localized description of the running stage, for screen readers.
  String? _stageLabel(BuildContext context, BootstrapStage? stage) {
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

  /// The mark's scale this frame: the entrance, the breath damped to nothing
  /// across the settle, and the small growth of the reveal.
  double get _scale {
    final breath = _still
        ? 0.0
        : 0.015 * math.sin(2 * math.pi * _breath.value) * (1 - _settle.value);
    final grow = _still ? 1.0 : 1 + 0.06 * _exit.value;
    return _markScale.value * (1 + breath) * grow;
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.state is BootstrapInProgress
        ? (widget.state as BootstrapInProgress).stage
        : null;

    // Light status-bar icons on the teal, until the splash leaves the tree.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Painted once: nothing above it animates its colours.
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.35, -1),
              end: Alignment(0.35, 1),
              colors: [Color(0xFF0E7C86), Color(0xFF0A5C64)],
            ),
          ),
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── The glow. Its own layer, so fading it in is a composite
                // rather than a repaint of half the screen ──
                // The boundary sits *above* the fade so the fade cannot dirty
                // the layer it shares with the backdrop. (Structure, not a
                // measured win: on the test phone the frame timing was the
                // same either way — see the F27-P01 record.)
                RepaintBoundary(
                  child: FadeTransition(
                    key: kSplashGlowKey,
                    opacity: _glowIn,
                    child: const RepaintBoundary(child: _Glow()),
                  ),
                ),

                // ── The mark, labelled with the app name: the one thing on
                // screen, and the first thing a screen reader announces.
                // Rebuilds a Transform and an Opacity per frame, never the
                // image under them ──
                RepaintBoundary(
                  child: Semantics(
                    label: context.strings.appName,
                    image: true,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _entrance,
                        _breath,
                        _settle,
                        _exit,
                      ]),
                      child: const RepaintBoundary(child: _BrandMark()),
                      builder: (context, child) => Opacity(
                        key: kSplashMarkKey,
                        opacity: _markIn.value,
                        child: Transform.scale(scale: _scale, child: child),
                      ),
                    ),
                  ),
                ),

                // ── Launch progress, for screen readers only ──
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: _stageLabel(context, stage),
                  child: const SizedBox.square(dimension: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The soft glow behind the mark. Static: only its opacity ever changes.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: kSplashGlowSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0x6B8CEBE1), Color(0x335AD2C8), Color(0x000E7C86)],
            stops: [0, 0.463, 1],
          ),
        ),
      ),
    );
  }
}

/// The brand mark. Its pixels say nothing a screen reader needs — the label
/// around it carries the app name.
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

// ---------------------------------------------------------------------------
// Launch error (unchanged from the original design)
// ---------------------------------------------------------------------------

class _LaunchError extends StatelessWidget {
  const _LaunchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).surfaceTealAlt,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 46,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        s.bootstrapErrorTitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: AppTypography.extraBold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        s.bootstrapErrorMessage,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: AppTypography.medium,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                30,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: Text(s.actionRetry),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
