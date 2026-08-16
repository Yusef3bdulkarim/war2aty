import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/cairo_day.dart';

// From `Waraqti.dc.html` → `sheetSnooze`.
const double _sheetRadius = AppRadii.xxl;
const double _sheetPadding = AppSpacing.xl;
const double _titleFontSize = 18;
const double _subtitleGap = 8;
const double _optionsGapAbove = 20;
const double _optionGap = 10;
const double _optionRadius = 13;
const double _optionPaddingV = 16;
const double _optionFontSize = 15;

/// The three snooze targets the sheet offers. Kept as a sealed class rather
/// than a raw `DateTime?` so the caller knows whether a custom picker is
/// expected.
sealed class SnoozeChoice {
  const SnoozeChoice();
}

/// A concrete instant — snooze the reminder's single alert to this time.
final class SnoozeToTime extends SnoozeChoice {
  const SnoozeToTime(this.time);
  final DateTime time;
}

/// The user picked «اختيار وقت جديد»; the caller opens a date-time picker and
/// resolves it themselves.
final class SnoozeCustom extends SnoozeChoice {
  const SnoozeCustom();
}

/// Shows the «تأجيل التذكير» sheet (F09-T12, `sheetSnooze` in the design).
///
/// Returns the user's choice, or `null` if they dismissed the sheet.
Future<SnoozeChoice?> showSnoozeSheet(BuildContext context) {
  return showModalBottomSheet<SnoozeChoice>(
    context: context,
    backgroundColor: AppColors.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (_) => const _SnoozeSheetBody(),
  );
}

/// The full «تأجيل» flow: shows [showSnoozeSheet], then — only for
/// [SnoozeCustom] — a date and time picker, both read as Cairo wall-clock
/// time like every other time this app collects (F09-T12). Shared by the
/// list card's own quick action and the details screen's, so the two never
/// drift into resolving "custom" differently.
///
/// Returns `null` at any point the user backs out, including a dismissed
/// sheet or a cancelled picker.
Future<DateTime?> pickReminderSnoozeTime(BuildContext context) async {
  final choice = await showSnoozeSheet(context);
  if (choice == null || !context.mounted) return null;

  return switch (choice) {
    SnoozeToTime(:final time) => time,
    SnoozeCustom() => _pickCustomSnoozeTime(context),
  };
}

Future<DateTime?> _pickCustomSnoozeTime(BuildContext context) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: now.add(const Duration(days: 3650)),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (time == null) return null;

  // Every wall-clock time in this app is read as Cairo time, regardless of
  // the device's own timezone — the same rule the alert offset picker
  // follows for the reminder form.
  return cairoInstant(date.year, date.month, date.day, time.hour, time.minute);
}

class _SnoozeSheetBody extends StatelessWidget {
  const _SnoozeSheetBody();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final now = DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _sheetPadding,
          _sheetPadding + 4,
          _sheetPadding,
          _sheetPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.reminderSnoozeSheetTitle,
              style: AppTypography.titleMedium.copyWith(
                fontSize: _titleFontSize,
                fontWeight: AppTypography.extraBold,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: _subtitleGap),
            Text(
              strings.reminderSnoozeSheetSubtitle,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: _optionsGapAbove),
            _SnoozeOption(
              label: strings.reminderSnoozeOptionOneHour,
              onTap: () => Navigator.pop(
                context,
                SnoozeToTime(now.add(const Duration(hours: 1))),
              ),
            ),
            const SizedBox(height: _optionGap),
            _SnoozeOption(
              label: strings.reminderSnoozeOptionTomorrow,
              onTap: () => Navigator.pop(
                context,
                SnoozeToTime(
                  DateTime(
                    now.year,
                    now.month,
                    now.day + 1,
                    now.hour,
                    now.minute,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _optionGap),
            _SnoozeOption(
              label: strings.reminderSnoozeOptionCustom,
              onTap: () => Navigator.pop(context, const SnoozeCustom()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnoozeOption extends StatelessWidget {
  const _SnoozeOption({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      color: colors.surfaceAlt,
      borderRadius: BorderRadius.circular(_optionRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_optionRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _optionPaddingV,
            horizontal: AppSpacing.lg,
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: _optionFontSize,
              fontWeight: AppTypography.semiBold,
              color: colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
