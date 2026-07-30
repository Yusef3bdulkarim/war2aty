import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the result page's summary card.
const double _cardPadding = 22;
const double _cardRadius = 22;
const double _cardGapBelow = 14;
const double _labelIconSize = 20;
const double _labelGap = 8;
const double _labelGapBelow = 10;
const double _labelFontSize = 13;
const double _labelSpacing = 0.4;
const double _summaryFontSize = 18;
const double _summaryHeight = 1.75;

/// Endpoints of the design's 150° gradient, as unit offsets from the centre.
const Alignment _gradientBegin = Alignment(-0.5, -0.866);
const Alignment _gradientEnd = Alignment(0.5, 0.866);

/// `0 12px 30px rgba(14,124,134,.28)` — the brand-tinted lift the design gives
/// this one card, so it reads as the page's answer rather than another block.
const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x470E7C86), blurRadius: 30, offset: Offset(0, 12)),
];

/// «الخلاصة» — the whole paper in one line, on the page's loudest surface.
///
/// It carries the star the design puts on AI-written text, so the user can
/// tell what the app worked out from what the paper says. The fuller
/// explanation is its own section further down (§4) rather than more text
/// here: this card has to stay short enough to read at a glance.
class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({required this.summary, super.key});

  /// The one-line summary. Never empty — `BuildAnalysisResult` drops the
  /// section instead of drawing an empty card.
  final String summary;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _cardGapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Plain [Alignment], not the directional variant: a CSS gradient
          // angle does not flip in an RTL container.
          gradient: LinearGradient(
            begin: _gradientBegin,
            end: _gradientEnd,
            colors: [colors.brandPrimary, colors.brandDeep],
          ),
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: _cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StrokeIcon(
                    StrokeGlyph.star,
                    color: colors.mintSoft,
                    size: _labelIconSize,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: _labelGap),
                  Flexible(
                    child: Text(
                      strings.resultSummaryLabel,
                      style: AppTypography.caption.copyWith(
                        fontSize: _labelFontSize,
                        fontWeight: AppTypography.extraBold,
                        letterSpacing: _labelSpacing,
                        color: colors.mintSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _labelGapBelow),
              Text(
                summary,
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: _summaryFontSize,
                  fontWeight: AppTypography.bold,
                  height: _summaryHeight,
                  color: colors.onBrand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
