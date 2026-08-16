import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';

// From `Waraqti.dc.html` → the manual form's «التاريخ»/«الوقت» row.
const double _rowGap = 12;
const double _sectionGapBelow = 18;
const double _fieldRadius = 14;
const double _fieldPaddingH = 16;
const double _fieldPaddingV = 15;
const double _fieldFontSize = 14.5;
const double _labelFontSize = 14;
const double _labelGapBelow = 8;
const double _iconSize = 18;

/// «التاريخ» / «الوقت» — the manual reminder's own event date and time, both
/// required (F09-T04): unlike a from-document reminder, there is no paper to
/// be silently missing an hour, so the form asks for both up front rather
/// than offering F09-T06's "no time" state.
///
/// Opens the platform's own date/time pickers — the design draws a plain
/// trigger row, not a custom picker face.
class ReminderDateTimePickers extends StatelessWidget {
  const ReminderDateTimePickers({
    required this.eventDate,
    required this.eventMinuteOfDay,
    required this.onDatePicked,
    required this.onTimePicked,
    super.key,
  });

  final DateTime? eventDate;
  final int? eventMinuteOfDay;
  final ValueChanged<DateTime> onDatePicked;
  final ValueChanged<int> onTimePicked;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionGapBelow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PickerField(
              label: strings.reminderDateLabel,
              hint: strings.reminderDatePickHint,
              value: eventDate == null
                  ? null
                  : formatDocumentDate(strings, eventDate!),
              glyph: StrokeGlyph.calendar,
              onTap: () => _pickDate(context),
            ),
          ),
          const SizedBox(width: _rowGap),
          Expanded(
            child: _PickerField(
              label: strings.reminderTimeLabel,
              hint: strings.reminderTimePickHint,
              value: eventMinuteOfDay == null
                  ? null
                  : formatWallClockTime(
                      strings,
                      eventMinuteOfDay! ~/ 60,
                      eventMinuteOfDay! % 60,
                    ),
              glyph: StrokeGlyph.clock,
              onTap: () => _pickTime(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: eventDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) onDatePicked(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final initial = eventMinuteOfDay == null
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: eventMinuteOfDay! ~/ 60,
            minute: eventMinuteOfDay! % 60,
          );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onTimePicked(picked.hour * 60 + picked.minute);
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.hint,
    required this.value,
    required this.glyph,
    required this.onTap,
  });

  final String label;
  final String hint;
  final String? value;
  final StrokeGlyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: AppTypography.caption.copyWith(
              fontSize: _labelFontSize,
              fontWeight: AppTypography.bold,
              color: colors.textSecondary,
            ),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: colors.error),
              ),
            ],
          ),
        ),
        const SizedBox(height: _labelGapBelow),
        Material(
          color: colors.card,
          borderRadius: BorderRadius.circular(_fieldRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_fieldRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _fieldPaddingH,
                vertical: _fieldPaddingV,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? hint,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: _fieldFontSize,
                        fontWeight: value == null
                            ? AppTypography.semiBold
                            : AppTypography.bold,
                        color: value == null
                            ? colors.textPlaceholder
                            : colors.ink,
                      ),
                    ),
                  ),
                  StrokeIcon(
                    glyph,
                    color: colors.brandPrimary,
                    size: _iconSize,
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
