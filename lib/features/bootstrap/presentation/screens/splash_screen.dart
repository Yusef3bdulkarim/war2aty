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
import '../widgets/pulsing_dots.dart';

/// Launch screen: brand splash while initializing, error state with retry if a
/// critical step fails.
///
/// The splash matches the Waraqti design (teal gradient, tiled document mark,
/// pulsing dots). The error state reuses the design's centred state-screen
/// pattern, since the design ships no dedicated launch-error comp.
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
        BootstrapSuccess() => _Splash(state: state),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({required this.state});

  final BootstrapState state;

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
    final stage = state is BootstrapInProgress
        ? (state as BootstrapInProgress).stage
        : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.35, -1),
            end: Alignment(0.35, 1),
            colors: [Color(0xFF0E7C86), Color(0xFF0A5C64)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  s.appName,
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge.copyWith(
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  s.appTagline,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: AppTypography.medium,
                  ),
                ),
                const SizedBox(height: 52),
                // Progress is the design's pulsing dots; the active stage is
                // announced to assistive tech without altering the visuals.
                Semantics(
                  liveRegion: true,
                  label: _stageLabel(context, stage),
                  child: const PulsingDots(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                          color: AppColors.light.surfaceTealAlt,
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
