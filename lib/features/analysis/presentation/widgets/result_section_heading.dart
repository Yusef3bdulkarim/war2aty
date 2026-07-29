import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the headings above the result page's lists.
const double _gapAbove = 20;
const double _gapBelow = 12;
const double _sideInset = 4;
const double _iconSize = 20;
const double _iconGap = 8;
const double _fontSize = 17;

/// The `<h2>` above a list on the result page — an icon and a name, outside
/// the card it introduces.
///
/// Shared by every list section so «أهم المعلومات» and «التواريخ والمواعيد»
/// cannot drift apart, and announced as a heading so a screen reader can jump
/// between the blocks of a long result.
class ResultSectionHeading extends StatelessWidget {
  const ResultSectionHeading({
    required this.glyph,
    required this.title,
    super.key,
  });

  final StrokeGlyph glyph;
  final String title;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _sideInset,
        _gapAbove,
        _sideInset,
        _gapBelow,
      ),
      child: Row(
        children: [
          StrokeIcon(glyph, color: colors.ink, size: _iconSize, strokeWidth: 2),
          const SizedBox(width: _iconGap),
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: _fontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
