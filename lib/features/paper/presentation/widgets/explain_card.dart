import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'paper_card_shell.dart';

const double _paragraphGap = 10;
const double _bodyFontSize = 17;
const double _bodyLineHeight = 1.85;

class ExplainCard extends StatelessWidget {
  const ExplainCard({
    required this.paragraphs,
    this.isHighlighted = false,
    super.key,
  });

  final List<String> paragraphs;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppTypography.bodyLead.copyWith(
      fontSize: _bodyFontSize,
      fontWeight: AppTypography.semiBold,
      height: _bodyLineHeight,
      color: colors.textBody,
    );

    return PaperCardShell(
      icon: StrokeGlyph.paperExplanationSheet,
      title: context.strings.paperExplainCardTitle,
      titleColor: colors.brandDeep,
      background: colors.card,
      borderColor: colors.borderSoft,
      iconBackground: colors.surfaceTealAlt,
      iconColor: colors.brandPrimary,
      isHighlighted: isHighlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, paragraph) in paragraphs.indexed) ...[
            if (index > 0) const SizedBox(height: _paragraphGap),
            Text(paragraph, style: style),
          ],
        ],
      ),
    );
  }
}
