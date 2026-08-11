import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/cairo_day.dart';
import '../../../../core/time/document_date_label.dart';
import 'reminder_status_pill.dart';

// From `Waraqti.dc.html` → the reminders list's own card, shared by every
// tab (F09-T11).
const double _cardRadius = 20;
const double _cardPadding = 17;
const double _borderWidth = 4;
const double _titleFontSize = 16;
const double _headerGapBelow = 8;
const double _rowGap = 6;
const double _rowIconSize = 15;
const double _rowGapInner = 6;
const double _rowFontSize = 13.5;
const double _actionsGapAbove = 12;
const double _actionGap = 9;
const double _actionHeight = 38;
const double _actionRadius = 11;
const double _actionFontSize = 13.5;

/// One reminder on the «التذكيرات» list (F09-T11) — the same card shape for
/// every tab, distinguished by [ReminderStatusPill] rather than by
/// structure, so «القادمة»/«الفائتة»/«المكتملة» never look like different
/// screens.
///
/// [onComplete]/[onSnooze] are only drawn when both the reminder is still
/// pending and a callback is given (F09-T12) — a missed/completed reminder
/// has nothing to complete or postpone, and an absent callback means
/// nowhere for the action to go yet.
class ReminderListItem extends StatelessWidget {
  const ReminderListItem({
    required this.reminder,
    this.onTap,
    this.onComplete,
    this.onSnooze,
    super.key,
  });

  final Reminder reminder;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSnooze;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    final due = reminder.nextAlert?.scheduledAt ?? reminder.eventInstant;
    final showActions =
        reminder.status.isPending && (onComplete != null || onSnooze != null);

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: AppShadows.card,
            border: BorderDirectional(
              start: BorderSide(
                color: _accentColor(colors),
                width: _borderWidth,
              ),
            ),
          ),
          padding: const EdgeInsets.all(_cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _titleFontSize,
                        fontWeight: AppTypography.extraBold,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  ReminderStatusPill(status: _pillStatus),
                ],
              ),
              const SizedBox(height: _headerGapBelow),
              Row(
                children: [
                  StrokeIcon(
                    StrokeGlyph.calendar,
                    color: colors.iconMuted,
                    size: _rowIconSize,
                  ),
                  const SizedBox(width: _rowGapInner),
                  Expanded(
                    child: Text(
                      due == null
                          ? formatDocumentDate(strings, reminder.eventDate)
                          : '${formatDocumentDate(strings, cairoLocalOf(due))}'
                                ' — ${formatWallClockTime(strings, cairoLocalOf(due).hour, cairoLocalOf(due).minute)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: _rowFontSize,
                        fontWeight: AppTypography.semiBold,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (reminder.description case final note?
                  when note.isNotEmpty) ...[
                const SizedBox(height: _rowGap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StrokeIcon(
                      StrokeGlyph.documentCheck,
                      color: colors.iconMuted,
                      size: _rowIconSize,
                    ),
                    const SizedBox(width: _rowGapInner),
                    Expanded(
                      child: Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: _rowFontSize - 1,
                          fontWeight: AppTypography.semiBold,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (showActions) ...[
                const SizedBox(height: _actionsGapAbove),
                Row(
                  children: [
                    if (onComplete != null)
                      Expanded(
                        child: _ActionChip(
                          label: strings.reminderCompleteAction,
                          background: colors.successTint,
                          foreground: colors.successInk,
                          onTap: onComplete!,
                        ),
                      ),
                    if (onComplete != null && onSnooze != null)
                      const SizedBox(width: _actionGap),
                    if (onSnooze != null)
                      Expanded(
                        child: _ActionChip(
                          label: strings.reminderSnoozeAction,
                          background: colors.surfaceTeal,
                          foreground: colors.brandPrimary,
                          onTap: onSnooze!,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ReminderStatusKind get _pillStatus {
    if (reminder.status.isCompleted) return ReminderStatusKind.completed;
    if (reminder.isOverdue()) return ReminderStatusKind.missed;
    return ReminderStatusKind.upcoming;
  }

  Color _accentColor(AppColors colors) => switch (_pillStatus) {
    ReminderStatusKind.upcoming => colors.brandPrimary,
    ReminderStatusKind.missed => colors.error,
    ReminderStatusKind.completed => colors.success,
  };
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        // A minimum, not a fixed, height — Large Text needs more room than
        // this to draw the label without clipping, and the button is free
        // to take it.
        minimumSize: const Size(0, _actionHeight),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_actionRadius),
        ),
        textStyle: AppTypography.labelMedium.copyWith(
          fontSize: _actionFontSize,
          fontWeight: AppTypography.bold,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
