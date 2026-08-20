import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';

// From `Waraqti.dc.html` → «معلومات من الورقة» on the create-from-document
// form.
const double _cardRadius = 16;
const double _rowPaddingH = 16;
const double _rowPaddingV = 15;
const double _labelFontSize = 14;
const double _valueFontSize = 15.5;
const double _headingFontSize = 13;
const double _headingGapBelow = 9;
const double _sectionGapBelow = 20;
const double _iconSize = 19;
const double _rowGap = 11;

/// «معلومات من الورقة» — the event date and time exactly as the analysis
/// read them, shown read-only above the alert picker (F09-T03).
///
/// [eventMinuteOfDay] `null` means the paper gave a day but no hour: the
/// time row says so in words rather than showing a blank or a guessed clock
/// (F09-T06) — the same rule the result screen's dates card follows.
class ReminderEventInfoCard extends StatelessWidget {
  const ReminderEventInfoCard({
    required this.eventDate,
    required this.eventMinuteOfDay,
    super.key,
  });

  final DateTime eventDate;
  final int? eventMinuteOfDay;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final minute = eventMinuteOfDay;

    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapBelow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.reminderFromDocumentInfoHeading,
            style: AppTypography.caption.copyWith(
              fontSize: _headingFontSize,
              fontWeight: AppTypography.extraBold,
              color: colors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: _headingGapBelow),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(_cardRadius),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _Row(
                  glyph: StrokeGlyph.calendar,
                  label: strings.reminderEventDateLabel,
                  value: formatDocumentDate(strings, eventDate),
                  showDivider: true,
                ),
                _Row(
                  glyph: StrokeGlyph.clock,
                  label: strings.reminderEventTimeLabel,
                  value: minute == null
                      ? null
                      : formatWallClockTime(strings, minute ~/ 60, minute % 60),
                  placeholder: strings.reminderEventTimeMissing,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.glyph,
    required this.label,
    required this.value,
    required this.showDivider,
    this.placeholder,
  });

  final StrokeGlyph glyph;
  final String label;
  final String? value;
  final String? placeholder;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowPaddingH,
        vertical: _rowPaddingV,
      ),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.borderSoft)),
            )
          : null,
      child: Row(
        children: [
          StrokeIcon(
            glyph,
            color: colors.brandPrimary,
            size: _iconSize,
            strokeWidth: 1.9,
          ),
          const SizedBox(width: _rowGap),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: _labelFontSize,
                fontWeight: AppTypography.semiBold,
                color: colors.textSecondary,
              ),
            ),
          ),
          // Flexible, not bare — unlike the label above, the value has no
          // Expanded of its own to shrink into under Large Text.
          Flexible(
            child: Text(
              value ?? placeholder!,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: value == null
                  ? AppTypography.labelCard.copyWith(
                      fontSize: _labelFontSize,
                      fontWeight: AppTypography.bold,
                      color: colors.textPlaceholder,
                    )
                  : AppTypography.labelCard.copyWith(
                      fontSize: _valueFontSize,
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
