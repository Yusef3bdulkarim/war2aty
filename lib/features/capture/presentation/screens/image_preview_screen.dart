import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/unit_rect.dart';
import '../capture_palette.dart';
import '../cubit/image_preview_cubit.dart';
import '../cubit/image_preview_state.dart';
import '../widgets/draggable_crop_overlay.dart';

const double _controlBox = 42;
const double _imageMaxWidth = 320;
const double _continueHeight = 68;
const double _buttonRadius = 15;

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({
    required this.imagePath,
    required this.onConfirmed,
    required this.onRetake,
    super.key,
  });

  final String imagePath;

  /// The crop/rotate is baked in and every other temp file this screen made
  /// is already gone (F39/F40-T21) — this is the explain pipeline's cue to
  /// start.
  final void Function(CapturedPhoto photo) onConfirmed;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: previewBackground,
        body: BlocConsumer<ImagePreviewCubit, ImagePreviewState>(
          listenWhen: (_, s) =>
              s is ImagePreviewConfirmed || s is ImagePreviewFailed,
          listener: (context, state) {
            switch (state) {
              case ImagePreviewConfirmed(:final photo):
                context.read<ImagePreviewCubit>().handOffToExplain();
                onConfirmed(photo);
              case ImagePreviewFailed():
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(context.strings.previewErrorMessage),
                    ),
                  );
              case ImagePreviewReady():
              case ImagePreviewProcessing():
                break;
            }
          },
          builder: (context, state) {
            final isProcessing = state is ImagePreviewProcessing;
            return SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    onRotate: isProcessing
                        ? null
                        : context.read<ImagePreviewCubit>().rotateClockwise,
                  ),
                  Expanded(
                    child: _ImageArea(
                      imagePath: imagePath,
                      quarterTurns: state.quarterTurns,
                      cropRect: state.cropRect,
                      isProcessing: isProcessing,
                      onCropChanged: isProcessing
                          ? null
                          : context.read<ImagePreviewCubit>().updateCrop,
                    ),
                  ),
                  _ActionBar(
                    onContinue: isProcessing
                        ? null
                        : context.read<ImagePreviewCubit>().confirm,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onRotate});

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            icon: Icons.help_outline_rounded,
            label: s.cropHelpLabel,
            onTap: null,
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

class _ImageArea extends StatelessWidget {
  const _ImageArea({
    required this.imagePath,
    required this.quarterTurns,
    required this.cropRect,
    required this.isProcessing,
    required this.onCropChanged,
  });

  final String imagePath;
  final int quarterTurns;
  final UnitRect cropRect;
  final bool isProcessing;
  final ValueChanged<UnitRect>? onCropChanged;

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
                child: DraggableCropOverlay(
                  cropRect: cropRect,
                  onCropChanged: onCropChanged,
                  enabled: !isProcessing,
                  child: RotatedBox(
                    quarterTurns: quarterTurns,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
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

class _ProcessingVeil extends StatelessWidget {
  const _ProcessingVeil();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onDark = AppColors.of(context).onBrand;

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

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final onDark = AppColors.of(context).onBrand;

    return Container(
      width: double.infinity,
      color: previewActionBar,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VoiceHintRow(onDark: onDark, label: s.cropVoiceHint),
          const SizedBox(height: AppSpacing.sm),
          _ContinueButton(
            label: s.cropContinue,
            onPressed: onContinue,
            background: AppColors.of(context).brandPrimary,
            foreground: onDark,
          ),
        ],
      ),
    );
  }
}

class _VoiceHintRow extends StatelessWidget {
  const _VoiceHintRow({required this.onDark, required this.label});

  final Color onDark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _AnimatedBars(),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: onDark.withValues(alpha: 0.7),
            fontWeight: AppTypography.semiBold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AnimatedBars extends StatefulWidget {
  const _AnimatedBars();

  @override
  State<_AnimatedBars> createState() => _AnimatedBarsState();
}

class _AnimatedBarsState extends State<_AnimatedBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = previewHintInk;
    return Semantics(
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bar(t, 0.0, 14, color),
              const SizedBox(width: 3),
              _bar(t, 0.3, 10, color),
              const SizedBox(width: 3),
              _bar(t, 0.15, 12, color),
            ],
          );
        },
      ),
    );
  }

  static Widget _bar(double t, double phase, double maxH, Color color) {
    final h = 4.0 + (maxH - 4) * (math.sin((t + phase) * math.pi).abs());
    return Container(
      width: 4,
      height: h.clamp(4.0, maxH),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

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
            child: Icon(icon, color: AppColors.of(context).onBrand, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;

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
          minimumSize: const Size.fromHeight(_continueHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelLarge.copyWith(
            fontSize: 17,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }
}
