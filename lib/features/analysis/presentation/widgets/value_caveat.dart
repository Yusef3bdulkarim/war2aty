import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the caution under a row's value.
const double _gap = 6;
const double _iconSize = 14;
const double _fontSize = 13;
const double _height = 1.5;

/// The caution that sits under one value in a list — «راجع المعلومة»,
/// «قراءة غير مؤكدة», «استنتاج من محتوى الورقة».
///
/// The same promise as `CaveatBadge`, in the flatter form the design uses
/// inside a row: a pill per row would turn a list of facts into a wall of
/// badges. It stays icon + words rather than colour alone, and reads as its
/// own sentence so a screen reader does not run it into the value above.
class ValueCaveat extends StatelessWidget {
  const ValueCaveat({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // On the caption's first line rather than centred, so the row
            // still reads properly once Large Text wraps it.
            padding: const EdgeInsets.only(top: 2),
            child: StrokeIcon(
              StrokeGlyph.warningTriangle,
              color: colors.warning,
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
                fontWeight: AppTypography.semiBold,
                height: _height,
                color: colors.warningInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
