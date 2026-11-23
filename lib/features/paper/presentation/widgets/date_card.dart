import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/paper_view.dart';
import 'paper_card_shell.dart';

const double _rowGap = 14;
const double _textGap = 12;
const double _badgeWidth = 76;
const double _badgeRadius = 16;
const double _badgeMonthFontSize = 13;
const double _badgeDayFontSize = 34;
const double _badgeDayLineHeight = 1.3;
const double _weekdayFontSize = 18;
const double _timeFontSize = 17;
const double _textFontSize = 15;
const double _textLineHeight = 1.7;
const double _bellSize = 52;
const double _bellBorderWidth = 2;

class DateCard extends StatelessWidget {
  const DateCard({
    required this.view,
    required this.onRemindMe,
    this.isHighlighted = false,
    super.key,
  });

  final PaperDateCardView view;
  final VoidCallback onRemindMe;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return PaperCardShell(
      icon: StrokeGlyph.calendar,
      title: strings.paperDateCardTitle,
      titleColor: colors.accentBlue,
      background: colors.card,
      borderColor: colors.borderSoft,
      iconBackground: colors.accentBlueTint,
      iconColor: colors.accentBlue,
      isHighlighted: isHighlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateBadge(
                month: view.month,
                day: view.day,
                accent: colors.accentBlue,
                ink: colors.ink,
              ),
              const SizedBox(width: _rowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.weekday,
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _weekdayFontSize,
                        fontWeight: AppTypography.extraBold,
                        color: colors.ink,
                      ),
                    ),
                    if (view.time case final time?)
                      Text(
                        time,
                        style: AppTypography.bodyLead.copyWith(
                          fontSize: _timeFontSize,
                          fontWeight: AppTypography.bold,
                          color: colors.textBody,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: _rowGap),
              _RemindButton(
                onPressed: onRemindMe,
                label: strings.paperDateCardBellLabel,
                color: colors.accentBlue,
                background: colors.card,
              ),
            ],
          ),
          const SizedBox(height: _textGap),
          Text(
            view.text,
            style: AppTypography.bodyLead.copyWith(
              fontSize: _textFontSize,
              fontWeight: AppTypography.semiBold,
              height: _textLineHeight,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.month,
    required this.day,
    required this.accent,
    required this.ink,
  });

  final String month;
  final String day;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: _badgeWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderCool),
        borderRadius: BorderRadius.circular(_badgeRadius),
      ),
      child: Column(
        children: [
          ColoredBox(
            color: accent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                month,
                textAlign: TextAlign.center,
                style: AppTypography.labelCard.copyWith(
                  fontSize: _badgeMonthFontSize,
                  fontWeight: AppTypography.bold,
                  color: colors.onBrand,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: AppTypography.labelCard.copyWith(
                fontSize: _badgeDayFontSize,
                fontWeight: AppTypography.extraBold,
                height: _badgeDayLineHeight,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindButton extends StatelessWidget {
  const _RemindButton({
    required this.onPressed,
    required this.label,
    required this.color,
    required this.background,
  });

  final VoidCallback onPressed;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Container(
        width: _bellSize,
        height: _bellSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(color: color, width: _bellBorderWidth),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Center(child: StrokeIcon(StrokeGlyph.bell, color: color)),
          ),
        ),
      ),
    );
  }
}
