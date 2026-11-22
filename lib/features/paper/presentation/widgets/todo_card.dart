import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'paper_card_shell.dart';

const double _bodyFontSize = 17;
const double _bodyLineHeight = 1.85;

class TodoCard extends StatelessWidget {
  const TodoCard({required this.text, this.isHighlighted = false, super.key});

  final String text;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PaperCardShell(
      icon: StrokeGlyph.paperChecklist,
      title: context.strings.paperTodoCardTitle,
      titleColor: colors.brandDeep,
      background: colors.card,
      borderColor: colors.borderSoft,
      iconBackground: colors.surfaceTealAlt,
      iconColor: colors.brandPrimary,
      isHighlighted: isHighlighted,
      child: Text(
        text,
        style: AppTypography.bodyLead.copyWith(
          fontSize: _bodyFontSize,
          fontWeight: AppTypography.bold,
          height: _bodyLineHeight,
          color: colors.ink,
        ),
      ),
    );
  }
}
