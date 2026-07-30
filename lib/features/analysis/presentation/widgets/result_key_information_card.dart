import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/documents/key_information.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../confidence_label.dart';
import 'result_section_heading.dart';
import 'value_caveat.dart';

// From `Waraqti.dc.html` → the result page's «أهم المعلومات» list.
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
const double _copyButton = 36;
const double _copyButtonRadius = 11;
const double _copyIconSize = 18;
const double _cardGapBelow = 14;

/// How long the "copied" confirmation stays up.
const Duration _copiedFeedback = Duration(seconds: 2);

/// «أهم المعلومات» — the labelled facts read off the paper, one row each.
///
/// Every row stands on its own: a value the analysis is unsure of, or worked
/// out rather than read, says so under itself. Confidence is never summarised
/// for the whole document and no row is ever badged "clear" (UX rules §5.9 and
/// §5.10) — a row with nothing to qualify simply carries no caution.
///
/// Each value can be copied, since these are the numbers a user retypes into a
/// payment app or reads out on the phone.
class ResultKeyInformationCard extends StatelessWidget {
  const ResultKeyInformationCard({required this.items, super.key});

  /// Never empty — `BuildAnalysisResult` drops the section otherwise.
  final List<KeyInformation> items;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultSectionHeading(
          glyph: StrokeGlyph.listLines,
          title: strings.resultKeyInformationTitle,
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
                  for (final (index, item) in items.indexed)
                    _InfoRow(item: item, isLast: index == items.length - 1),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One labelled fact.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.item, required this.isLast});

  final KeyInformation item;

  /// The design hairlines every row but the last.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    // Two separate cautions, and a row can carry both: how sure the reading is
    // (§30.5's band) and whether the paper said it at all.
    final caveats = [
      ?confidenceLabel(strings, item.confidence),
      if (item.source == InfoSource.inferred) strings.resultActionInferred,
    ];

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
                  StrokeGlyph.listLines,
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
                    item.label,
                    style: AppTypography.caption.copyWith(
                      fontSize: _labelFontSize,
                      fontWeight: AppTypography.semiBold,
                      color: colors.iconSubtle,
                    ),
                  ),
                  const SizedBox(height: _labelGapBelow),
                  Text(
                    item.value,
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: _valueFontSize,
                      fontWeight: AppTypography.bold,
                      color: colors.ink,
                    ),
                  ),
                  for (final caveat in caveats) ...[
                    const SizedBox(height: _caveatGapAbove),
                    ValueCaveat(text: caveat),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _rowGap),
            _CopyButton(item: item),
          ],
        ),
      ),
    );
  }
}

/// Puts one value on the clipboard.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.item});

  final KeyInformation item;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return SizedBox.square(
      dimension: _copyButton,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_copyButtonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_copyButtonRadius),
          onTap: () => _copy(context),
          child: Semantics(
            button: true,
            label: strings.resultCopyValueLabel(item.label),
            child: Center(
              child: StrokeIcon(
                StrokeGlyph.copy,
                color: colors.textMuted,
                size: _copyIconSize,
                strokeWidth: 1.9,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: item.value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.ocrTextCopied),
        duration: _copiedFeedback,
      ),
    );
  }
}
