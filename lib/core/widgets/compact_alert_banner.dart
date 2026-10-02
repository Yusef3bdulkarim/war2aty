import 'package:flutter/material.dart';

import '../icons/stroke_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// The owner's result-screen review (F21 locked decisions #2 and #10).
const double _minHeight = 48;
const double _radius = 8;
const double _paddingH = 12;
const double _paddingV = 10;
const double _gap = 10;
const double _iconSize = 18;
const double _fontSize = 14;
const double _height = 1.5;

/// A slim amber caution: a warning icon and one short text, on the warning
/// tint.
///
/// At least 48 px tall, never a fixed height: the text wraps and the banner
/// grows with it, so a long legal disclaimer or Large Text is never clipped.
/// It reads as a caution without its colour — the icon and the words carry it
/// (CLAUDE.md, UX rule §5.16).
class CompactAlertBanner extends StatelessWidget {
  const CompactAlertBanner({
    required this.text,
    this.semanticsLabel,
    super.key,
  });

  final String text;

  /// What a screen reader says instead of [text] alone — e.g. with the name of
  /// the block the banner belongs to in front of it.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      container: true,
      label: semanticsLabel ?? text,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.warningTint,
            border: Border.all(color: colors.warningBorder),
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _paddingH,
              vertical: _paddingV,
            ),
            child: Row(
              children: [
                StrokeIcon(
                  StrokeGlyph.warningTriangle,
                  color: colors.warning,
                  size: _iconSize,
                  strokeWidth: 2,
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: _fontSize,
                      fontWeight: AppTypography.semiBold,
                      height: _height,
                      color: colors.warningInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
