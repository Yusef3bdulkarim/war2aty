import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` — matches the `camPerm` sheet proportions.
const double _sheetRadius = 26;
const double _sheetSide = 24;
const double _sheetBottom = 34;
const double _handleWidth = 40;
const double _handleHeight = 5;
const double _iconBox = 64;
const double _iconRadius = 19;
const double _primaryHeight = 54;
const double _secondaryHeight = 50;
const double _buttonRadius = 15;

/// Shows a quality warning as a modal bottom sheet and returns the user's
/// choice: `true` to continue despite poor quality, `false` to retake.
///
/// The sheet is not dismissible — the user must pick one of the two options.
Future<bool> showQualityAlertSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const QualityAlertSheet(),
  ).then((value) => value ?? false);
}

/// Bottom-sheet content warning the user that the captured photo is poor.
///
/// Two actions: retake (primary, teal — the recommended path) and continue
/// (secondary, amber tint — proceed despite the warning). Pops with `true`
/// for continue, `false` for retake.
class QualityAlertSheet extends StatelessWidget {
  const QualityAlertSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_sheetRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          _sheetSide,
          AppSpacing.md,
          _sheetSide,
          _sheetBottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GrabHandle(),
              const SizedBox(height: 22),
              const _WarningBadge(),
              const SizedBox(height: 18),
              Text(
                s.qualityAlertTitle,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 20,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.qualityAlertMessage,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: AppTypography.medium,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              _SheetButton(
                label: s.qualityAlertRetake,
                onPressed: () => Navigator.of(context).pop(false),
                background: colors.brandPrimary,
                foreground: colors.onBrand,
                height: _primaryHeight,
                fontSize: 17,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SheetButton(
                label: s.qualityAlertContinue,
                onPressed: () => Navigator.of(context).pop(true),
                background: colors.warningTint,
                foreground: colors.warningInk,
                height: _secondaryHeight,
                fontSize: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: _handleWidth,
        height: _handleHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.light.border,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

class _WarningBadge extends StatelessWidget {
  const _WarningBadge();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Container(
      width: _iconBox,
      height: _iconBox,
      decoration: BoxDecoration(
        color: colors.warningTint,
        borderRadius: BorderRadius.circular(_iconRadius),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFFC77B12), size: 32),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.height,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onPressed;
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
