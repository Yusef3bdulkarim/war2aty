import 'package:flutter/material.dart';
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
import '../widgets/paper_plane_logo.dart';
import '../widgets/pulsing_dots.dart';

/// Launch screen: brand splash while initializing, error state with retry if a
/// critical step fails.
///
/// The splash matches the Waraqti design (teal gradient). The mark itself is
/// the animation: a folded paper dart glides in, unfolds into the page, and the
/// magnifier drops onto it — see [PaperPlaneLogo] for the drawing and its own
/// internal timeline. The screen only adds the copy underneath:
///   0.75 → 0.85  app name slides up and fades in
///   0.80 → 0.90  tagline slides up and fades in
///   0.88 → 0.98  progress dots appear
/// After the entrance, an ambient loop keeps the mark breathing.
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
  // ── Entrance (one-shot: flight, unfold, magnifier, copy) ──
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: kLogoEntranceDuration,
  );

  // ── Ambient loop (starts after the entrance, drives the mark's breathing) ──
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  // ── Derived entrance curves ──
  late final Animation<double> _nameFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.75, 0.85, curve: Curves.easeOut),
  );

  late final Animation<double> _nameSlide = Tween<double>(begin: 24, end: 0)
      .animate(
        CurvedAnimation(
          parent: _entrance,
          curve: const Interval(0.75, 0.85, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.80, 0.90, curve: Curves.easeOut),
  );

  late final Animation<double> _taglineSlide = Tween<double>(begin: 18, end: 0)
      .animate(
        CurvedAnimation(
          parent: _entrance,
          curve: const Interval(0.80, 0.90, curve: Curves.easeOutCubic),
        ),
      );

  late final Animation<double> _dotsFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.88, 0.98, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ambient.repeat();
        widget.onEntranceFinished();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Under reduced motion, show the settled mark at once and release the
    // launch immediately — the hold exists to protect the animation, so with no
    // animation to protect it would just be six seconds of dead time. Keeps the
    // ambient ticker idle too, rather than burning frames nobody sees.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      widget.onEntranceFinished();
    } else {
      _entrance.forward();
    }
  }

  /// `didChangeDependencies` runs again whenever an ancestor changes; the
  /// entrance must only ever be kicked off once.
  bool _started = false;

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
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

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final stage = widget.state is BootstrapInProgress
        ? (widget.state as BootstrapInProgress).stage
        : null;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _ambient]),
        builder: (context, _) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.35, -1),
                end: Alignment(0.35, 1),
                colors: [Color(0xFF0E7C86), Color(0xFF0A5C64)],
              ),
            ),
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // ── The animated mark ──
                  PaperPlaneLogo(
                    progress: _entrance.value,
                    ambient: _ambient.value,
                    size: 200,
                  ),

                  const SizedBox(height: 8),

                  // ── App name ──
                  Transform.translate(
                    offset: Offset(0, _nameSlide.value),
                    child: Opacity(
                      opacity: _nameFade.value,
                      child: Text(
                        s.appName,
                        textAlign: TextAlign.center,
                        style: AppTypography.displayLarge.copyWith(
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Tagline ──
                  Transform.translate(
                    offset: Offset(0, _taglineSlide.value),
                    child: Opacity(
                      opacity: _taglineFade.value,
                      child: Text(
                        s.appTagline,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Pulsing dots ──
                  Opacity(
                    opacity: _dotsFade.value,
                    child: Semantics(
                      liveRegion: true,
                      label: _stageLabel(context, stage),
                      child: const PulsingDots(),
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          );
        },
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
