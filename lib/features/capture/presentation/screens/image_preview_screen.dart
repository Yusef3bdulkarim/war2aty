import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/image_quality_result.dart';
import '../capture_palette.dart';
import '../cubit/image_preview_cubit.dart';
import '../cubit/image_preview_state.dart';
import '../widgets/crop_frame.dart';
import '../widgets/quality_alert_sheet.dart';

// From `Waraqti.dc.html` → `preview`.
const double _controlBox = 42;
const double _imageMaxWidth = 320;
const double _primaryHeight = 54;
const double _secondaryHeight = 50;
const double _buttonRadius = 15;

/// The crop / rotate / confirm screen the user lands on after acquiring an
/// image.
///
/// The design merges those three steps into this one «قص الصورة» screen: a
/// fixed framing guide (not a draggable crop), a working 90° rotate, and a
/// confirm / retake footer. Rotation is shown live with a cheap widget turn and
/// only baked into a file when the user confirms.
class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({
    required this.imagePath,
    required this.onSessionCreated,
    required this.onRetake,
    super.key,
  });

  /// The acquired image to preview, before any rotation.
  final String imagePath;

  /// Hands the created analysis session to the next stage (F04).
  final void Function(AnalysisSession session) onSessionCreated;

  /// Backs out to re-acquire the image (camera or gallery).
  final VoidCallback onRetake;

  Future<void> _onQualityKnown(
    BuildContext context,
    ImageQualityResult quality,
  ) async {
    if (quality.overall == ImageQuality.poor) {
      final shouldContinue = await showQualityAlertSheet(context);
      if (!context.mounted) return;
      if (!shouldContinue) {
        onRetake();
        return;
      }
    }
    if (context.mounted) {
      await context.read<ImagePreviewCubit>().proceed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: previewBackground,
      body: BlocConsumer<ImagePreviewCubit, ImagePreviewState>(
        listenWhen: (_, s) =>
            s is ImagePreviewConfirmed ||
            s is ImagePreviewFailed ||
            s is ImagePreviewSessionCreated,
        listener: (context, state) {
          switch (state) {
            case ImagePreviewConfirmed(:final quality):
              unawaited(_onQualityKnown(context, quality));
            case ImagePreviewSessionCreated(:final session):
              onSessionCreated(session);
            case ImagePreviewFailed():
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(context.strings.previewErrorMessage)),
                );
            case ImagePreviewReady():
            case ImagePreviewProcessing():
            case ImagePreviewCreatingSession():
              break;
          }
        },
        builder: (context, state) {
          final isProcessing =
              state is ImagePreviewProcessing ||
              state is ImagePreviewCreatingSession;
          return SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: onRetake,
                  onRotate: isProcessing
                      ? null
                      : context.read<ImagePreviewCubit>().rotateClockwise,
                ),
                Expanded(
                  child: _ImageArea(
                    imagePath: imagePath,
                    quarterTurns: state.quarterTurns,
                    isProcessing: isProcessing,
                  ),
                ),
                _ActionBar(
                  onUse: isProcessing
                      ? null
                      : context.read<ImagePreviewCubit>().confirm,
                  onRetake: isProcessing ? null : onRetake,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Back, title, and the rotate control.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onRotate});

  final VoidCallback onBack;
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.close_rounded,
            label: s.actionBack,
            onTap: onBack,
          ),
          Expanded(
            child: Text(
              s.previewTitle,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.light.onBrand,
              ),
            ),
          ),
          _CircleButton(
            icon: Icons.rotate_right_rounded,
            label: s.previewRotateLabel,
            onTap: onRotate,
          ),
        ],
      ),
    );
  }
}

/// The framed, rotatable image, with a processing veil while it exports.
class _ImageArea extends StatelessWidget {
  const _ImageArea({
    required this.imagePath,
    required this.quarterTurns,
    required this.isProcessing,
  });

  final String imagePath;
  final int quarterTurns;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _imageMaxWidth),
                child: CropFrame(
                  child: RotatedBox(
                    quarterTurns: quarterTurns,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      // A missing/undecodable file must not crash the preview —
                      // show a neutral placeholder and let the user retake.
                      errorBuilder: (context, _, _) =>
                          const _ImageUnavailable(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isProcessing) const Positioned.fill(child: _ProcessingVeil()),
      ],
    );
  }
}

/// Fallback when the image file cannot be shown.
class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white.withValues(alpha: 0.4),
          size: 48,
        ),
      ),
    );
  }
}

/// The dim veil + spinner shown while the confirmed image is prepared.
class _ProcessingVeil extends StatelessWidget {
  const _ProcessingVeil();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onDark = AppColors.light.onBrand;

    return ColoredBox(
      color: previewBackground.withValues(alpha: 0.6),
      child: Semantics(
        liveRegion: true,
        label: s.previewProcessing,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: onDark.withValues(alpha: 0.85)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.previewProcessing,
              style: AppTypography.bodyMedium.copyWith(
                color: onDark.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hint and the confirm / retake buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onUse, required this.onRetake});

  final VoidCallback? onUse;
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onDark = AppColors.light.onBrand;

    return Container(
      width: double.infinity,
      color: previewActionBar,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: previewHintInk,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  s.previewHint,
                  style: AppTypography.caption.copyWith(
                    color: previewHintInk,
                    fontWeight: AppTypography.semiBold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PreviewButton(
            label: s.previewUseImage,
            onPressed: onUse,
            background: AppColors.light.brandPrimary,
            foreground: onDark,
            height: _primaryHeight,
            fontSize: 17,
          ),
          const SizedBox(height: 9),
          _PreviewButton(
            label: s.previewRetake,
            onPressed: onRetake,
            background: Colors.white.withValues(alpha: 0.1),
            foreground: onDark,
            height: _secondaryHeight,
            fontSize: 16,
          ),
        ],
      ),
    );
  }
}

/// A translucent circular control in the top bar. A `null` [onTap] disables it.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _controlBox,
            height: _controlBox,
            child: Icon(icon, color: AppColors.light.onBrand, size: 22),
          ),
        ),
      ),
    );
  }
}

/// One full-width footer button. A `null` [onPressed] disables it.
class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.height,
    required this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          minimumSize: Size.fromHeight(height),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelLarge.copyWith(
            fontSize: fontSize,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }
}
