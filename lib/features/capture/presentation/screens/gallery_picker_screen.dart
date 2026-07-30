import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/captured_photo.dart';
import '../cubit/gallery_picker_cubit.dart';
import '../cubit/gallery_picker_state.dart';

/// Opens the system photo picker as soon as it appears, then routes on the
/// outcome.
///
/// There is no custom gallery UI — the OS picker is the interface. This screen
/// only holds the brief wait behind it and the error path, so a picker that
/// fails to open does not dead-end the user.
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({
    required this.onPicked,
    required this.onCancelled,
    super.key,
  });

  /// Hands the chosen photo to the next stage (review, F03-T06).
  final ValueChanged<CapturedPhoto> onPicked;

  /// The user backed out, or is leaving after an error — return to Home.
  final VoidCallback onCancelled;

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GalleryPickerCubit>().pick();
  }

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: BlocConsumer<GalleryPickerCubit, GalleryPickerState>(
          // The terminal outcomes are hand-offs, not screens: navigate from the
          // listener and let the builder handle only what stays on screen.
          listenWhen: (_, s) =>
              s is GalleryPickerSelected || s is GalleryPickerCancelled,
          listener: (context, state) {
            switch (state) {
              case GalleryPickerSelected(:final photo):
                widget.onPicked(photo);
              case GalleryPickerCancelled():
                widget.onCancelled();
              case GalleryPickerPicking():
              case GalleryPickerError():
                break;
            }
          },
          builder: (context, state) => switch (state) {
            GalleryPickerError() => _GalleryError(
              onRetry: context.read<GalleryPickerCubit>().pick,
              onBack: widget.onCancelled,
            ),
            // Picking, and the transient moment after a terminal state while the
            // listener navigates, both show the neutral wait.
            _ => const _Opening(),
          },
        ),
      ),
    );
  }
}

/// The brief wait shown behind the system picker.
class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return Semantics(
      liveRegion: true,
      label: s.galleryOpening,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.brandPrimary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.galleryOpening,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The error state, with a retry and a way back.
class _GalleryError extends StatelessWidget {
  const _GalleryError({required this.onRetry, required this.onBack});

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: colors.iconSubtle,
              size: 48,
              semanticLabel: s.galleryErrorTitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.galleryErrorTitle,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(color: colors.ink),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.galleryErrorMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: colors.brandPrimary,
                foregroundColor: colors.onBrand,
                minimumSize: const Size.fromHeight(52),
                textStyle: AppTypography.labelLarge,
              ),
              child: Text(s.actionRetry),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                minimumSize: const Size.fromHeight(48),
                textStyle: AppTypography.labelLarge,
              ),
              child: Text(s.actionBack),
            ),
          ],
        ),
      ),
    );
  }
}
