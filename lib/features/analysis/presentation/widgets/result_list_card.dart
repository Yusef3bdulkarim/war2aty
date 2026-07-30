import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import 'result_section_heading.dart';

// From `Waraqti.dc.html` → the result page's «المستندات المطلوبة» list.
const double _cardPaddingH = 18;
const double _cardPaddingV = 8;
const double _cardGapBelow = 14;
const double _rowPaddingV = 12;
const double _rowGap = 11;
const double _markerSize = 8;
const double _markerBoxWidth = 22;
const double _textFontSize = 15;
const double _numberFontSize = 13;

/// A plain list of Arabic lines under a heading — «المستندات المطلوبة» and
/// «الخطوات بالترتيب».
///
/// Both are strings the analysis wrote with no structure of their own, so they
/// share one card. The only difference is the marker: papers to bring are a
/// set and take a dot, steps happen in order and are numbered — the sequence
/// is information, and a dotted list would throw it away.
class ResultListCard extends StatelessWidget {
  const ResultListCard({
    required this.glyph,
    required this.title,
    required this.items,
    this.numbered = false,
    super.key,
  });

  final StrokeGlyph glyph;
  final String title;

  /// Never empty — `BuildAnalysisResult` drops the section otherwise.
  final List<String> items;

  final bool numbered;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultSectionHeading(glyph: glyph, title: title),
        Padding(
          padding: const EdgeInsets.only(bottom: _cardGapBelow),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _cardPaddingH,
                vertical: _cardPaddingV,
              ),
              child: Column(
                children: [
                  for (final (index, item) in items.indexed)
                    _ListRow(
                      item: item,
                      position: index + 1,
                      numbered: numbered,
                      isLast: index == items.length - 1,
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

/// One line, with its marker.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.item,
    required this.position,
    required this.numbered,
    required this.isLast,
  });

  final String item;
  final int position;
  final bool numbered;

  /// The design hairlines every row but the last.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colors.surfaceAlt)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _rowPaddingV),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _markerBoxWidth,
              child: numbered
                  // The number is read out: "step two" is part of the line's
                  // meaning, unlike the dot, which is decoration.
                  ? Text(
                      '$position',
                      style: AppTypography.caption.copyWith(
                        fontSize: _numberFontSize,
                        fontWeight: AppTypography.extraBold,
                        color: colors.brandPrimary,
                      ),
                    )
                  : const ExcludeSemantics(child: _Dot()),
            ),
            const SizedBox(width: _rowGap),
            Expanded(
              child: Text(
                item,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: _textFontSize,
                  fontWeight: AppTypography.semiBold,
                  color: colors.textBody,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The teal bullet the design puts beside a paper to bring.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      // Sits on the first line of the text rather than at its top edge.
      padding: const EdgeInsets.only(top: _markerSize),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Container(
          width: _markerSize,
          height: _markerSize,
          decoration: BoxDecoration(
            color: colors.brandPrimary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
