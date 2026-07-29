import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/analysis_warning.dart';

// From `Waraqti.dc.html` → the result page's «تنبيه مهم» card.
const double _cardPadding = 16;
const double _cardGapBelow = 14;
const double _titleIconSize = 20;
const double _titleGap = 8;
const double _titleGapBelow = 8;
const double _titleFontSize = 15;
const double _textFontSize = 14.5;
const double _textHeight = 1.7;
const double _warningGap = 10;

/// «تنبيه مهم» — the medical, legal, financial and government disclaimers.
///
/// §4 puts this above the figures, and that placement is the point: it is a
/// caution to read *before* acting on anything further down the page, not a
/// footnote under it. The block carries an icon and a heading as well as its
/// amber fill, so it still reads as a warning without colour (CLAUDE.md).
///
/// `WarningKind` chooses no icon of its own here: the design draws one
/// treatment for all four, and a per-kind mark would be invention.
class ResultWarningsCard extends StatelessWidget {
  const ResultWarningsCard({required this.warnings, super.key});

  /// Never empty — `BuildAnalysisResult` drops the section otherwise.
  final List<AnalysisWarning> warnings;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _cardGapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningTint,
          border: Border.all(color: colors.warningBorder),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StrokeIcon(
                    StrokeGlyph.warningTriangle,
                    color: colors.warning,
                    size: _titleIconSize,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: _titleGap),
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        strings.resultWarningsTitle,
                        style: AppTypography.labelCard.copyWith(
                          fontSize: _titleFontSize,
                          fontWeight: AppTypography.extraBold,
                          color: colors.warningInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _titleGapBelow),
              for (final (index, warning) in warnings.indexed) ...[
                if (index > 0) const SizedBox(height: _warningGap),
                Text(
                  warning.text,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: _textFontSize,
                    fontWeight: AppTypography.semiBold,
                    height: _textHeight,
                    color: colors.warningInk,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
