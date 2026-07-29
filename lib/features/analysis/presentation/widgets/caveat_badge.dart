import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the result page's «استنتاج من محتوى الورقة» pill.
const double _paddingH = 10;
const double _paddingV = 4;
const double _gap = 5;
const double _iconSize = 13;
const double _fontSize = 12;

/// The amber pill that qualifies a value: «راجع المعلومة», «قراءة غير مؤكدة»,
/// «استنتاج من محتوى الورقة».
///
/// One badge for all three because they are the same promise to the user —
/// *this line is not something the paper states plainly*. It carries an icon
/// and words, never colour alone (CLAUDE.md), and it is announced as its own
/// sentence so a screen reader does not run it into the value above it.
class CaveatBadge extends StatelessWidget {
  const CaveatBadge({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningTint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _paddingH,
            vertical: _paddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                // Sits on the first line of the label rather than centred, so
                // the badge still reads properly when Large Text wraps it.
                padding: const EdgeInsets.only(top: 2),
                child: StrokeIcon(
                  StrokeGlyph.info,
                  color: colors.warningInk,
                  size: _iconSize,
                  strokeWidth: 2.2,
                ),
              ),
              const SizedBox(width: _gap),
              Flexible(
                child: Text(
                  text,
                  style: AppTypography.caption.copyWith(
                    fontSize: _fontSize,
                    fontWeight: AppTypography.bold,
                    color: colors.warningInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
