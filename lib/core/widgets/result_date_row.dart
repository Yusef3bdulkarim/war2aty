import 'package:flutter/material.dart';

import '../documents/analysis_date.dart';
import '../documents/confidence_label.dart';
import '../icons/stroke_icon.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../time/document_date_label.dart';
import 'caveated_value.dart';
import 'date_selection_sheet.dart';

// From `Waraqti.dc.html` → the result page's «التواريخ والمواعيد» card. Since
// F21 the rows and the button sit in `ResultDetailsCard`, not a card of their
// own.
const double _rowGap = 13;
const double _tileSize = 52;
const double _tileRadius = 15;
const double _tilePadding = 6;
const double _tileDayFontSize = 18;
const double _tileMonthFontSize = 10;
const double _roleFontSize = 13;
const double _valueFontSize = 16.5;
const double _valueGapAbove = 2;
const double _noteFontSize = 12.5;
const double _noteGapAbove = 3;
const double _buttonHeight = 48;
const double _buttonRadius = 14;
const double _buttonFontSize = 15.5;
const double _buttonIconSize = 19;

/// «إنشاء تذكير» — the way from a paper's date to a reminder about it.
///
/// With one date there is nothing to ask. With several, the user says which
/// one they meant before anything else happens (UX rule §5.8) — the app never
/// picks for them, not even when the analysis has an opinion.
class ResultReminderButton extends StatelessWidget {
  const ResultReminderButton({
    required this.dates,
    required this.onCreateReminder,
    super.key,
  });

  final List<AnalysisDate> dates;
  final ValueChanged<AnalysisDate> onCreateReminder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SizedBox(
      height: _buttonHeight,
      child: FilledButton.icon(
        onPressed: () => _start(context),
        style: FilledButton.styleFrom(
          backgroundColor: colors.surfaceTeal,
          foregroundColor: colors.brandPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
          textStyle: AppTypography.labelCard.copyWith(
            fontSize: _buttonFontSize,
            fontWeight: AppTypography.bold,
          ),
        ),
        icon: StrokeIcon(
          // The design's bell, shared with the reminders tab and Home's card.
          StrokeGlyph.navReminders,
          color: colors.brandPrimary,
          size: _buttonIconSize,
          strokeWidth: 2,
        ),
        label: Text(strings.resultCreateReminder),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final chosen = await chooseReminderDate(context, dates: dates);
    // Dismissed without choosing — nothing is scheduled on the user's behalf.
    if (chosen != null) onCreateReminder(chosen);
  }
}

/// One date: the day on a tile, then its role, the written-out date with its
/// cautions, and what the paper does or does not say about the time.
///
/// That last line is the point of the row: a paper that names a day but no
/// hour says so («مافيهاش وقت محدد») instead of being given a plausible-looking
/// one (UX rule §5.6).
///
/// The picking sheet draws its own, shorter row — it is choosing between dates
/// rather than reporting them, and the time line would be noise there.
class ResultDateRow extends StatelessWidget {
  const ResultDateRow({required this.date, super.key});

  final AnalysisDate date;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    final time = date.time;
    final caveat = confidenceLabel(strings, date.confidence);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayTile(date: date.date),
        const SizedBox(width: _rowGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.label,
                style: AppTypography.caption.copyWith(
                  fontSize: _roleFontSize,
                  fontWeight: AppTypography.semiBold,
                  color: colors.iconSubtle,
                ),
              ),
              const SizedBox(height: _valueGapAbove),
              CaveatedValue(
                value: Text(
                  formatDocumentDate(strings, date.date),
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: _valueFontSize,
                    fontWeight: AppTypography.extraBold,
                    color: colors.ink,
                  ),
                ),
                caveats: [?caveat],
              ),
              const SizedBox(height: _noteGapAbove),
              Text(
                // Never blank: silence about the time would read as "no time
                // needed" rather than "the paper does not say".
                time == null
                    ? strings.resultDateNoTime
                    : formatWallClockTime(strings, time.hour, time.minute),
                style: AppTypography.caption.copyWith(
                  fontSize: _noteFontSize,
                  fontWeight: AppTypography.semiBold,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The teal square carrying the day and its month.
class _DayTile extends StatelessWidget {
  const _DayTile({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return Container(
      // A minimum rather than a fixed square: under Large Text the day and
      // month need the room, and a clipped date is worse than a wider tile.
      constraints: const BoxConstraints(
        minWidth: _tileSize,
        minHeight: _tileSize,
      ),
      padding: const EdgeInsets.all(_tilePadding),
      decoration: BoxDecoration(
        color: colors.surfaceTealAlt,
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
      // Hidden from assistive technology: the full date is spelled out beside
      // it, and reading "25 أغسطس" twice helps nobody.
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: AppTypography.titleLarge.copyWith(
                fontSize: _tileDayFontSize,
                fontWeight: AppTypography.extraBold,
                height: 1,
                color: colors.brandDeep,
              ),
            ),
            Text(
              strings.monthName(date.month),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.micro.copyWith(
                fontSize: _tileMonthFontSize,
                fontWeight: AppTypography.bold,
                color: colors.brandDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
