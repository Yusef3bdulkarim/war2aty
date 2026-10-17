import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/reminders/quick_reminder_date.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/document_date_label.dart';
import '../../../../core/widgets/forward_chevron.dart';

// From the approved F29 prototype (`docs/design/F29-reminders-empty-mockups.html`
// → concept D's `.qbtn`). The icon box keeps its size under Large Text, like
// every other icon box in the app: the two lines of text grow and the row
// grows with them.
const double _rowGap = 9;
const double _rowRadius = 18;
const double _rowPaddingH = 14;
const double _rowPaddingV = 13;
const double _iconBox = 36;
const double _iconBoxRadius = 11;
const double _iconSize = 19;
const double _contentGap = 11;
const double _labelFontSize = 15;
const double _dateFontSize = 13;
const double _chevronSize = 18;

/// The three ready-made dates on the empty reminders list — «بكرة», «بعد
/// أسبوع», «آخر الشهر» — each opening the manual form with its date and time
/// already filled in (F29, concept D).
///
/// Knows nothing about cubits, routes or `get_it`: it is handed the resolved
/// [slots] and reports a tap through [onSelected]. The arithmetic behind a
/// slot lives in `core/reminders/quick_reminder_date.dart`, and what a tap
/// does is the screen's business (T09/T11) — so this widget can be pumped on
/// its own with a fixed clock, which is the only way its date lines are
/// testable at all.
class RemindersQuickCreate extends StatelessWidget {
  const RemindersQuickCreate({
    required this.slots,
    required this.onSelected,
    super.key,
  });

  /// Resolved by the caller, so the dates come from one clock read rather
  /// than from a widget reaching for [DateTime.now] mid-build.
  final List<QuickReminderSlot> slots;

  final ValueChanged<QuickReminderSlot> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, slot) in slots.indexed) ...[
          if (index > 0) const SizedBox(height: _rowGap),
          _QuickRow(slot: slot, onTap: () => onSelected(slot)),
        ],
      ],
    );
  }
}

/// One quick date: its name, the date it resolves to, and a chevron.
class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.slot, required this.onTap});

  final QuickReminderSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_rowRadius),
      // The prototype's 1 px, which is [BorderSide]'s own default width.
      side: BorderSide(color: colors.borderCool),
    );

    final label = _label(strings, slot.kind);
    final date = _dateLine(strings, slot);

    // One button to a screen reader, reading the name and the date it means
    // — two separate nodes would make the user swipe twice to learn what the
    // row does. The house pattern (`upcoming_reminder_card.dart`).
    return Semantics(
      button: true,
      label: '$label. $date',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.card,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          // No `minHeight` standing in for the prototype's 56 px: the icon
          // box and the padding already put the row well past it, so the
          // constraint would never bind and would read as if it were doing
          // something. The floor is asserted on the rendered height instead.
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _rowPaddingH,
              vertical: _rowPaddingV,
            ),
            child: Row(
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  decoration: BoxDecoration(
                    color: colors.surfaceTeal,
                    borderRadius: BorderRadius.circular(_iconBoxRadius),
                  ),
                  child: Center(
                    child: StrokeIcon(
                      StrokeGlyph.calendar,
                      color: colors.brandPrimary,
                      size: _iconSize,
                    ),
                  ),
                ),
                const SizedBox(width: _contentGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.labelCard.copyWith(
                          fontSize: _labelFontSize,
                          fontWeight: AppTypography.extraBold,
                          color: colors.ink,
                        ),
                      ),
                      // Left to wrap rather than ellipsized: the date is the
                      // whole promise of the row, and at 1.6× it no longer
                      // fits on one line on a small phone.
                      Text(
                        date,
                        style: AppTypography.caption.copyWith(
                          fontSize: _dateFontSize,
                          fontWeight: AppTypography.semiBold,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _contentGap),
                ForwardChevron(color: colors.iconMuted, size: _chevronSize),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the user reads as the row's name.
String _label(AppStrings s, QuickReminderDate kind) => switch (kind) {
  QuickReminderDate.tomorrow => s.reminderQuickTomorrow,
  QuickReminderDate.nextWeek => s.reminderQuickNextWeek,
  QuickReminderDate.endOfMonth => s.reminderQuickEndOfMonth,
};

/// The date the row resolves to — `16 أكتوبر 2026 — 9:00 صباحًا`.
///
/// Written exactly the way `alertTimeLabel` writes a hand-picked alert, from
/// the same two formatters, so a date on this screen and a date in the form
/// the row opens read identically. No weekday name: the app has none in
/// either language, and the copy table settled this line as these two
/// formatters rather than as new strings — so «الخميس» from the prototype is
/// deliberately not here.
String _dateLine(AppStrings s, QuickReminderSlot slot) {
  final date = slot.eventDate;
  final minute = slot.eventMinuteOfDay;
  return '${formatDocumentDate(s, date)} — '
      '${formatWallClockTime(s, minute ~/ 60, minute % 60)}';
}
