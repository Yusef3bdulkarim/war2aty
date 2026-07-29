import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/document_analysis.dart';
import '../confidence_label.dart';
import '../document_kind_label.dart';
import 'caveat_badge.dart';

// From `Waraqti.dc.html` → the result page's title card.
const double _cardPadding = 18;
const double _cardGapBelow = 14;
const double _chipPaddingH = 12;
const double _chipPaddingV = 4;
const double _chipFontSize = 12.5;
const double _chipGapBelow = 10;
const double _titleFontSize = 22;
const double _badgeGapAbove = 10;

/// The first thing on the result page: what kind of paper this is, and what it
/// is called.
///
/// Both come from the analysis, so both can be wrong — when it is not sure of
/// them, the card says so rather than presenting a guess as a fact (UX rules
/// §5.9 and §5.11). The kind and the title share one confidence band, so one
/// badge covers the card.
///
/// The design also draws a pencil button beside the title; renaming a paper
/// belongs to the saved-document screen (F08), so it is left out here rather
/// than shipped as a button that does nothing.
class ResultHeaderCard extends StatelessWidget {
  const ResultHeaderCard({required this.analysis, super.key});

  final DocumentAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    final caveat = confidenceLabel(strings, analysis.kindConfidence);

    return Padding(
      padding: const EdgeInsets.only(bottom: _cardGapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KindChip(label: documentKindLabel(strings, analysis.kind)),
              const SizedBox(height: _chipGapBelow),
              Semantics(
                header: true,
                child: Text(
                  analysis.title,
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: _titleFontSize,
                    fontWeight: AppTypography.extraBold,
                    color: colors.ink,
                  ),
                ),
              ),
              if (caveat != null) ...[
                const SizedBox(height: _badgeGapAbove),
                CaveatBadge(text: caveat),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The amber pill naming the kind of paper.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.warningTint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _chipPaddingH,
          vertical: _chipPaddingV,
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: _chipFontSize,
            fontWeight: AppTypography.bold,
            color: colors.warning,
          ),
        ),
      ),
    );
  }
}
