import 'package:flutter/material.dart';

import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

const double _radius = 18;
const double _borderWidth = 1.5;
const double _paddingH = 16;
const double _paddingV = 14;
const double _iconBox = 44;
const double _iconBoxRadius = 12;
const double _iconSize = 22;
const double _gap = 12;
const double _titleFontSize = 15;
const double _subtitleFontSize = 13;
const double _chevronSize = 20;

/// «عرض النص المستخرج» as a card in the unsupported page's content (F23 #5,
/// Option B): what was read off the paper, one tap away, and copyable there.
class ExtractedTextEntryCard extends StatelessWidget {
  const ExtractedTextEntryCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    // The chevron points onward: towards the end of the line, so left in RTL.
    final mirror = Directionality.of(context) == TextDirection.ltr;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
      side: BorderSide(color: colors.borderCool, width: _borderWidth),
    );

    // A button to a screen reader too: `InkWell` alone only adds the tap.
    return Semantics(
      button: true,
      child: Material(
        color: colors.card,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _paddingH,
              vertical: _paddingV,
            ),
            child: Row(
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  decoration: BoxDecoration(
                    color: colors.surfaceTeal,
                    borderRadius: BorderRadius.circular(_iconBoxRadius),
                  ),
                  child: Center(
                    child: StrokeIcon(
                      StrokeGlyph.documentSteps,
                      color: colors.brandPrimary,
                      size: _iconSize,
                    ),
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.resultShowExtractedText,
                        style: AppTypography.labelCard.copyWith(
                          fontSize: _titleFontSize,
                          fontWeight: AppTypography.bold,
                          color: colors.ink,
                        ),
                      ),
                      Text(
                        strings.analysisExtractedTextCardSubtitle,
                        style: AppTypography.caption.copyWith(
                          fontSize: _subtitleFontSize,
                          fontWeight: AppTypography.medium,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _gap),
                Transform.flip(
                  flipX: mirror,
                  child: StrokeIcon(
                    StrokeGlyph.chevronForward,
                    color: colors.textSecondary,
                    size: _chevronSize,
                    strokeWidth: 2,
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
