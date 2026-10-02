import 'package:flutter/material.dart';

import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_typography.dart';

const double _paddingH = 14;
const double _paddingV = 6;
const double _iconSize = 18;
const double _gap = 8;
const double _fontSize = 13.5;

/// A green pill with a check — a reassurance under a failure page's message,
/// such as «المحاولة دي متحسبتش من تحليلاتك النهارده» (F23 #5).
///
/// The check and the words say it; the green only underlines it.
class FailureNoteChip extends StatelessWidget {
  const FailureNoteChip({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.successTint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingH,
          vertical: _paddingV,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StrokeIcon(
              StrokeGlyph.check,
              color: colors.successInk,
              size: _iconSize,
              strokeWidth: 2.2,
            ),
            const SizedBox(width: _gap),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  fontSize: _fontSize,
                  fontWeight: AppTypography.bold,
                  color: colors.successInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
