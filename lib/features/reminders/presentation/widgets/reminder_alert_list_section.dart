import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/alert_time_label.dart';
import '../../../../core/reminders/alert_time_offset.dart';
import '../../../../core/reminders/reminder_due_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/reminder_alert_draft.dart';
import 'alert_offset_picker_sheet.dart';

// From `Waraqti.dc.html` → «مواعيد التنبيه» on both reminder forms.
const int kMaxReminderAlerts = 3;
const double _labelGapBelow = 9;
const double _rowGap = 9;
const double _rowRadius = 14;
const double _rowPaddingH = 15;
const double _rowPaddingV = 14;
const double _rowFontSize = 15;
const double _checkSize = 22;
const double _addButtonFontSize = 15;
const double _sectionGapBelow = 20;
const double _warningRadius = 12;
const double _warningPaddingH = 13;
const double _warningPaddingV = 12;
const double _warningGap = 8;
const double _warningFontSize = 14;
const double _warningGapBelow = 12;
const double _suggestionRadius = 13;
const double _suggestionPaddingV = 13;
const double _suggestionGap = 8;
const double _suggestionFontSize = 14.5;
const double _suggestionGapBelow = 20;

/// «مواعيد التنبيه» — the alert times a reminder-in-progress has, with the
/// way to add up to [kMaxReminderAlerts] and remove any of them (F09-T08).
///
/// Shared by the create-from-document form (F09-T03) and the manual form
/// (F09-T04) — see F09-T02. [eventInstant] being `null` means the paper (or
/// the not-yet-filled manual form) gave no event time, so the picker this
/// opens offers only a hand-picked absolute time, never a relative preset
/// with nothing to be relative to (F09-T06).
///
/// [missingEventTimeSuggestion], when given, is a ready-to-use alert instant
/// — the design's own «اقتراح: نبّهني الساعة 10 صباحًا» — shown alongside an
/// explanation of *why* there is nothing to pick from, instead of a bare
/// empty list. Pass it only when the paper genuinely had a date but no
/// time; a manual reminder whose date/time simply have not been filled in
/// yet is a different situation and gets no such explanation.
class ReminderAlertListSection extends StatelessWidget {
  const ReminderAlertListSection({
    required this.alerts,
    required this.eventInstant,
    required this.onAdd,
    required this.onRemove,
    this.missingEventTimeSuggestion,
    super.key,
  });

  final List<ReminderAlertDraft> alerts;
  final DateTime? eventInstant;
  final ValueChanged<ReminderAlertDraft> onAdd;
  final ValueChanged<int> onRemove;
  final DateTime? missingEventTimeSuggestion;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    final showMissingTimeHint =
        alerts.isEmpty && missingEventTimeSuggestion != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.reminderAlertsSectionLabel,
          style: AppTypography.caption.copyWith(
            fontSize: 14,
            fontWeight: AppTypography.bold,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: _labelGapBelow),
        for (final (index, alert) in alerts.indexed) ...[
          if (index > 0) const SizedBox(height: _rowGap),
          _AlertRow(
            alert: alert,
            onRemove: () => onRemove(index),
            removeLabel: strings.reminderRemoveAlertLabel,
          ),
        ],
        if (showMissingTimeHint) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: _warningPaddingH,
              vertical: _warningPaddingV,
            ),
            decoration: BoxDecoration(
              color: colors.warningTint,
              borderRadius: BorderRadius.circular(_warningRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StrokeIcon(StrokeGlyph.info, color: colors.warning, size: 17),
                const SizedBox(width: _warningGap),
                Expanded(
                  child: Text(
                    strings.reminderMissingEventTimeWarning,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: _warningFontSize,
                      fontWeight: AppTypography.medium,
                      height: 1.65,
                      color: colors.warningInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _warningGapBelow),
          Material(
            color: colors.surfaceTeal,
            borderRadius: BorderRadius.circular(_suggestionRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(_suggestionRadius),
              onTap: () =>
                  onAdd(ReminderAlertDraft(time: missingEventTimeSuggestion!)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _suggestionPaddingV,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StrokeIcon(
                      StrokeGlyph.sparkle,
                      color: colors.brandDeep,
                      size: 17,
                    ),
                    const SizedBox(width: _suggestionGap),
                    Text(
                      strings.reminderSuggestedAlertTime(
                        formatClockTime(strings, missingEventTimeSuggestion!),
                      ),
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _suggestionFontSize,
                        fontWeight: AppTypography.bold,
                        color: colors.brandDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _suggestionGapBelow),
        ],
        if (alerts.length < kMaxReminderAlerts) ...[
          if (alerts.isNotEmpty) const SizedBox(height: _rowGap),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextButton.icon(
              onPressed: () => _addAlert(context),
              style: TextButton.styleFrom(
                foregroundColor: colors.brandPrimary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: StrokeIcon(
                StrokeGlyph.plus,
                color: colors.brandPrimary,
                size: 18,
                strokeWidth: 2.2,
              ),
              label: Text(
                strings.reminderAddAnotherAlert,
                style: AppTypography.labelMedium.copyWith(
                  fontSize: _addButtonFontSize,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: _sectionGapBelow),
      ],
    );
  }

  Future<void> _addAlert(BuildContext context) async {
    final used = alerts
        .map((a) => a.offset)
        .whereType<AlertTimeOffset>()
        .toSet();
    final draft = await showAlertOffsetPickerSheet(
      context,
      eventInstant: eventInstant,
      excludedOffsets: used,
    );
    if (draft != null) onAdd(draft);
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.alert,
    required this.onRemove,
    required this.removeLabel,
  });

  final ReminderAlertDraft alert;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_rowRadius),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _rowPaddingH,
          vertical: _rowPaddingV,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                alertTimeLabel(strings, alert.time, offset: alert.offset),
                style: AppTypography.labelCard.copyWith(
                  fontSize: _rowFontSize,
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: removeLabel,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: _checkSize,
                  height: _checkSize,
                  child: Icon(
                    Icons.close,
                    size: _checkSize - 4,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
