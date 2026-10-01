import 'package:flutter/material.dart';

import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

const double _radius = 18;
const double _padding = 16;
const double _titleGap = 12;
const double _titleFontSize = 15.5;
const double _tileGap = 10;
const double _tileRadius = 14;
const double _tilePadding = 12;
const double _iconSize = 22;
const double _innerGap = 6;
const double _labelFontSize = 14;

/// «لو فتحته، هنقولك:» on the consent-off page (F23 #9): what turning the
/// analysis back on would give, in four tiles. Not a nudge with a switch —
/// the page leads to Settings, and the choice stays the user's.
class ConsentValueCard extends StatelessWidget {
  const ConsentValueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    Widget pair(_Value start, _Value end) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Tile(value: start)),
          const SizedBox(width: _tileGap),
          Expanded(child: _Tile(value: end)),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                strings.analysisConsentValueTitle,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGap),
            pair(
              _Value(
                StrokeGlyph.documentSteps,
                strings.analysisConsentValueType,
              ),
              _Value(
                StrokeGlyph.sparkle,
                strings.analysisConsentValueKeyPoints,
              ),
            ),
            const SizedBox(height: _tileGap),
            pair(
              _Value(
                StrokeGlyph.checkSquare,
                strings.analysisConsentValueRequired,
              ),
              _Value(StrokeGlyph.clock, strings.analysisConsentValueDates),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Value {
  const _Value(this.glyph, this.label);

  final StrokeGlyph glyph;
  final String label;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value});

  final _Value value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_tilePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StrokeIcon(
              value.glyph,
              color: colors.brandPrimary,
              size: _iconSize,
              strokeWidth: 1.9,
            ),
            const SizedBox(height: _innerGap),
            Text(
              value.label,
              style: AppTypography.labelCard.copyWith(
                fontSize: _labelFontSize,
                fontWeight: AppTypography.bold,
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
