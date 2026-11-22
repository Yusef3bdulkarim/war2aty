import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'paper_card_shell.dart';

const double _bodyFontSize = 17;
const double _bodyLineHeight = 1.85;

class CautionCard extends StatelessWidget {
  const CautionCard({
    required this.text,
    this.isHighlighted = false,
    super.key,
  });

  final String text;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PaperCardShell(
      icon: StrokeGlyph.warningTriangle,
      title: context.strings.paperCautionCardTitle,
      titleColor: colors.warningInk,
      background: colors.warningTint,
      borderColor: colors.warningBorder,
      iconBackground: colors.warning,
      iconColor: colors.onBrand,
      isHighlighted: isHighlighted,
      child: Text(
        text,
        style: AppTypography.bodyLead.copyWith(
          fontSize: _bodyFontSize,
          fontWeight: AppTypography.bold,
          height: _bodyLineHeight,
          color: colors.warningInk,
        ),
      ),
    );
  }
}
