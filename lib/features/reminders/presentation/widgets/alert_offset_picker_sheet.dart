import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/alert_time_label.dart';
import '../../../../core/reminders/alert_time_offset.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/cairo_day.dart';
import '../models/reminder_alert_draft.dart';

// From `Waraqti.dc.html` → the reminder forms' alert-offset chip row,
// reshaped as a sheet so the same list works for both "add" and "the paper
// gave no time" (F09-T06), which offers only the last option below.
const double _sheetRadius = 26;
const double _sheetPaddingTop = 12;
const double _sheetPaddingH = 22;
const double _sheetPaddingBottom = 30;
const double _grabberWidth = 40;
const double _grabberHeight = 5;
const double _grabberGapBelow = 18;
const double _titleFontSize = 19;
const double _titleGapBelow = 16;
const double _optionGap = 9;
const double _optionRadius = 13;
const double _optionPaddingH = 15;
const double _optionPaddingV = 15;
const double _optionFontSize = 15;

/// Lets the user add one alert to a reminder-in-progress: an offset relative
/// to [eventInstant] (F09-T05), or a hand-picked absolute date and time.
///
/// [eventInstant] `null` means there is no event time to offset from — every
/// preset needs one, so only the custom option is shown (F09-T06).
/// [excludedOffsets] hides presets already used by another alert on the same
/// reminder, so the user can't add the same one twice.
///
/// Answers `null` if dismissed without choosing.
Future<ReminderAlertDraft?> showAlertOffsetPickerSheet(
  BuildContext context, {
  required DateTime? eventInstant,
  Set<AlertTimeOffset> excludedOffsets = const {},
}) {
  return showModalBottomSheet<ReminderAlertDraft>(
    context: context,
    backgroundColor: AppColors.light.card,
    // Scroll-controlled so the sheet sizes to its content (up to four
    // options) instead of the default half-screen, which clips on a short
    // viewport or under Large Text.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (_) => _AlertOffsetPickerSheet(
      eventInstant: eventInstant,
      excludedOffsets: excludedOffsets,
    ),
  );
}

class _AlertOffsetPickerSheet extends StatelessWidget {
  const _AlertOffsetPickerSheet({
    required this.eventInstant,
    required this.excludedOffsets,
  });

  final DateTime? eventInstant;
  final Set<AlertTimeOffset> excludedOffsets;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    final eventInstant = this.eventInstant;

    final presets = eventInstant == null
        ? const <AlertTimeOffset>[]
        : AlertTimeOffset.values
              .where((o) => !excludedOffsets.contains(o))
              .toList(growable: false);

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                strings.reminderAlertPickerTitle,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGapBelow),
            for (final offset in presets) ...[
              _Option(
                label: alertOffsetLabel(strings, offset),
                onTap: () => Navigator.of(context).pop(
                  ReminderAlertDraft(
                    // Non-null: `presets` is only ever non-empty when
                    // `eventInstant` is set (see above).
                    time: offset.applyTo(eventInstant!),
                    offset: offset,
                  ),
                ),
              ),
              const SizedBox(height: _optionGap),
            ],
            _Option(
              label: strings.reminderAlertOffsetCustom,
              onTap: () => _pickCustomTime(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;

    Navigator.of(context).pop(
      ReminderAlertDraft(
        // Every wall-clock time in this app is read as Cairo time,
        // regardless of the device's own timezone (`cairoInstant`) — so a
        // custom "10 صباحًا" means the same instant on any phone.
        time: cairoInstant(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_optionRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_optionRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _optionPaddingH,
            vertical: _optionPaddingV,
          ),
          child: Text(
            label,
            textAlign: TextAlign.start,
            style: AppTypography.labelCard.copyWith(
              fontSize: _optionFontSize,
              fontWeight: AppTypography.bold,
              color: colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
