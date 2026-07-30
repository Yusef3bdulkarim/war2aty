import 'package:flutter/material.dart';

import '../../../../core/documents/analysis_date.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';

// From `Waraqti.dc.html` → the «اختار التاريخ» sheet.
const double _sheetRadius = 26;
const double _sheetPaddingTop = 12;
const double _sheetPaddingH = 22;
const double _sheetPaddingBottom = 30;
const double _sheetMaxHeightFactor = 0.88;
const double _grabberWidth = 40;
const double _grabberHeight = 5;
const double _grabberGapBelow = 18;
const double _titleFontSize = 19;
const double _titleGapBelow = 6;
const double _messageFontSize = 14;
const double _messageHeight = 1.7;
const double _messageGapBelow = 18;
const double _optionGap = 10;
const double _optionPaddingH = 16;
const double _optionPaddingV = 15;
const double _optionRadius = 16;
const double _optionBorderWidth = 1.5;
const double _optionRowGap = 13;
const double _optionIconBox = 44;
const double _optionIconBoxRadius = 13;
const double _optionIconSize = 22;
const double _optionRoleFontSize = 15;
const double _optionDateFontSize = 13.5;
const double _optionDateGapAbove = 2;
const double _pillGapAbove = 6;
const double _pillPaddingH = 9;
const double _pillPaddingV = 3;
const double _pillGap = 4;
const double _pillIconSize = 12;
const double _pillFontSize = 12;

/// Settles which date a reminder is for.
///
/// With one date there is nothing to ask, so the user is not asked. With
/// several the app does not choose for them (UX rule §5.8) — not even when the
/// analysis has an opinion, which travels as a badge on the options instead.
///
/// Answers `null` when the paper has no dates at all, or when the user backed
/// out of the sheet: either way nothing is scheduled on their behalf.
///
/// Shared by the dates card and the page's action bar so both reach a reminder
/// the same way.
Future<AnalysisDate?> chooseReminderDate(
  BuildContext context, {
  required List<AnalysisDate> dates,
}) async {
  if (dates.isEmpty) return null;
  if (dates.length == 1) return dates.first;
  return showDateSelectionSheet(context, dates: dates);
}

/// Asks which of the paper's dates the reminder is for, and answers with it —
/// or with `null` if the sheet was dismissed.
///
/// Prefer [chooseReminderDate], which decides whether there is anything to ask
/// in the first place.
Future<AnalysisDate?> showDateSelectionSheet(
  BuildContext context, {
  required List<AnalysisDate> dates,
}) => showModalBottomSheet<AnalysisDate>(
  context: context,
  backgroundColor: AppColors.light.card,
  // Sized by its content up to the design's cap, so two dates do not get the
  // same tall sheet as eight.
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
  ),
  builder: (_) => DateSelectionSheet(dates: dates),
);

/// The body of that sheet.
///
/// Every date on the paper is offered, not only the ones the analysis would
/// remind about: its suggestion is a badge on the option, never a filter that
/// hides the date the user actually came for.
class DateSelectionSheet extends StatelessWidget {
  const DateSelectionSheet({required this.dates, super.key});

  final List<AnalysisDate> dates;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                margin: const EdgeInsets.only(bottom: _grabberGapBelow),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                strings.resultPickDateTitle,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGapBelow),
            Text(
              strings.resultPickDateMessage,
              style: AppTypography.bodySmall.copyWith(
                fontSize: _messageFontSize,
                fontWeight: AppTypography.medium,
                height: _messageHeight,
                color: colors.textCaption,
              ),
            ),
            const SizedBox(height: _messageGapBelow),
            for (final (index, date) in dates.indexed) ...[
              if (index > 0) const SizedBox(height: _optionGap),
              _DateOption(date: date),
            ],
          ],
        ),
      ),
    );
  }
}

/// One choosable date.
class _DateOption extends StatelessWidget {
  const _DateOption({required this.date});

  final AnalysisDate date;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_optionRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_optionRadius),
        onTap: () => Navigator.of(context).pop(date),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.borderSoft,
              width: _optionBorderWidth,
            ),
            borderRadius: BorderRadius.circular(_optionRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _optionPaddingH,
            vertical: _optionPaddingV,
          ),
          child: Row(
            children: [
              Container(
                width: _optionIconBox,
                height: _optionIconBox,
                decoration: BoxDecoration(
                  color: colors.surfaceTealAlt,
                  borderRadius: BorderRadius.circular(_optionIconBoxRadius),
                ),
                child: Center(
                  child: StrokeIcon(
                    StrokeGlyph.calendar,
                    color: colors.brandPrimary,
                    size: _optionIconSize,
                  ),
                ),
              ),
              const SizedBox(width: _optionRowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.label,
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _optionRoleFontSize,
                        fontWeight: AppTypography.extraBold,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: _optionDateGapAbove),
                    Text(
                      formatDocumentDate(strings, date.date),
                      style: AppTypography.caption.copyWith(
                        fontSize: _optionDateFontSize,
                        fontWeight: AppTypography.semiBold,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: _pillGapAbove),
                    // Both states are spelled out. Showing a badge only on the
                    // suggested date would leave the others looking like an
                    // oversight rather than a deliberate "for reference".
                    if (date.isReminderWorthy)
                      _Pill(
                        label: strings.resultDateReminderWorthy,
                        glyph: StrokeGlyph.check,
                        foreground: colors.successInk,
                        background: colors.successTint,
                      )
                    else
                      _Pill(
                        label: strings.resultDateDisplayOnly,
                        foreground: colors.textMuted,
                        background: colors.surfaceAlt,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small tag under a date.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
    this.glyph,
  });

  final String label;
  final Color foreground;
  final Color background;
  final StrokeGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _pillPaddingH,
            vertical: _pillPaddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph case final glyph?) ...[
                StrokeIcon(
                  glyph,
                  color: foreground,
                  size: _pillIconSize,
                  strokeWidth: 3,
                ),
                const SizedBox(width: _pillGap),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    fontSize: _pillFontSize,
                    fontWeight: AppTypography.bold,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
