import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';
import '../../domain/entities/analysis_date.dart';
import '../confidence_label.dart';
import 'date_selection_sheet.dart';
import 'result_section_heading.dart';
import 'value_caveat.dart';

// From `Waraqti.dc.html` → the result page's «التواريخ والمواعيد» card.
const double _cardPadding = 18;
const double _cardGapBelow = 14;
const double _rowGap = 13;
const double _rowSpacing = 14;
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
const double _caveatGapAbove = 6;
const double _buttonHeight = 48;
const double _buttonRadius = 14;
const double _buttonFontSize = 15.5;
const double _buttonIconSize = 19;

/// «التواريخ والمواعيد» — every date the analysis found, and what each is for.
///
/// Each row says its role in the analysis's own words, the day written out,
/// and one line about the time. That last line is the point of the block: a
/// paper that names a day but no hour says so («مافيهاش وقت محدد») instead of
/// being given a plausible-looking one (UX rule §5.6).
///
/// It is also the branch point into a reminder — and where the user, not the
/// app, picks which date that reminder is for.
class ResultDatesCard extends StatelessWidget {
  const ResultDatesCard({
    required this.dates,
    this.onCreateReminder,
    super.key,
  });

  /// In the order the analysis reported them — never empty, since
  /// `BuildAnalysisResult` drops the section otherwise.
  final List<AnalysisDate> dates;

  /// Starts a reminder for the date the user settled on.
  ///
  /// Absent until there is somewhere for it to go (F09), and the button is
  /// left out entirely while it is — better no button than one that does
  /// nothing.
  final ValueChanged<AnalysisDate>? onCreateReminder;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultSectionHeading(
          glyph: StrokeGlyph.calendar,
          title: strings.resultDatesTitle,
        ),
        Padding(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, date) in dates.indexed) ...[
                    if (index > 0) const SizedBox(height: _rowSpacing),
                    _DateRow(date: date),
                  ],
                  if (onCreateReminder case final onCreateReminder?) ...[
                    const SizedBox(height: _rowSpacing),
                    _ReminderButton(
                      dates: dates,
                      onCreateReminder: onCreateReminder,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// «إنشاء تذكير» — the way from a paper's date to a reminder about it.
///
/// With one date there is nothing to ask. With several, the user says which
/// one they meant before anything else happens (UX rule §5.8) — the app never
/// picks for them, not even when the analysis has an opinion.
class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.dates, required this.onCreateReminder});

  final List<AnalysisDate> dates;
  final ValueChanged<AnalysisDate> onCreateReminder;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
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

/// One date: the day on a tile, then its role, the written-out date, and what
/// the paper does or does not say about the time.
///
/// The picking sheet draws its own, shorter row — it is choosing between dates
/// rather than reporting them, and the time line would be noise there.
class _DateRow extends StatelessWidget {
  const _DateRow({required this.date});

  final AnalysisDate date;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
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
              Text(
                formatDocumentDate(strings, date.date),
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: _valueFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
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
              if (caveat != null) ...[
                const SizedBox(height: _caveatGapAbove),
                ValueCaveat(text: caveat),
              ],
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
    const colors = AppColors.light;
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
