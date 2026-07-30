import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/money/document_amount_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/analysis_amount.dart';
import '../confidence_label.dart';
import 'result_section_heading.dart';
import 'value_caveat.dart';

// Follows the «أهم المعلومات» list in `Waraqti.dc.html`, which is where the
// design puts a money figure.
const double _rowPaddingH = 16;
const double _rowPaddingV = 15;
const double _rowGap = 12;
const double _iconBox = 40;
const double _iconBoxRadius = 12;
const double _iconSize = 20;
const double _labelFontSize = 13;
const double _labelGapBelow = 2;
const double _valueFontSize = 16;
const double _caveatGapAbove = 7;
const double _cardGapBelow = 14;

/// «المبالغ» — the money the paper is about.
///
/// Amounts get their own block rather than sitting among the other facts:
/// they carry a currency, they are the figure a user is most likely to act on,
/// and a wrong one costs the most. Each keeps its own caution, so a figure the
/// analysis is unsure of is never presented as the amount to pay.
class ResultAmountsCard extends StatelessWidget {
  const ResultAmountsCard({required this.amounts, super.key});

  /// Never empty — `BuildAnalysisResult` drops the section otherwise.
  final List<AnalysisAmount> amounts;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultSectionHeading(
          glyph: StrokeGlyph.money,
          title: strings.resultAmountsTitle,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: _cardGapBelow),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.card,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              child: Column(
                children: [
                  for (final (index, amount) in amounts.indexed)
                    _AmountRow(
                      amount: amount,
                      isLast: index == amounts.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One figure, with what it is for.
class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.amount, required this.isLast});

  final AnalysisAmount amount;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    final caveat = confidenceLabel(strings, amount.confidence);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colors.surfaceAlt)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _rowPaddingH,
          vertical: _rowPaddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  StrokeGlyph.money,
                  color: colors.brandPrimary,
                  size: _iconSize,
                ),
              ),
            ),
            const SizedBox(width: _rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amount.label,
                    style: AppTypography.caption.copyWith(
                      fontSize: _labelFontSize,
                      fontWeight: AppTypography.semiBold,
                      color: colors.iconSubtle,
                    ),
                  ),
                  const SizedBox(height: _labelGapBelow),
                  Text(
                    formatDocumentAmount(
                      strings,
                      amount.value,
                      amount.currency,
                    ),
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: _valueFontSize,
                      fontWeight: AppTypography.bold,
                      color: colors.ink,
                    ),
                  ),
                  if (caveat != null) ...[
                    const SizedBox(height: _caveatGapAbove),
                    ValueCaveat(text: caveat),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
