import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the reminders list card's status pill (F09-T11).
const double _paddingH = 10;
const double _paddingV = 4;
const double _fontSize = 12;

/// «القادمة» / «الفائتة» / «المكتملة» — a reminder's status as shown on its
/// own card, computed the same way the list buckets it ([ReminderListItem]
/// picks the value from [Reminder.status]/[Reminder.isOverdue]).
enum ReminderStatusKind { upcoming, missed, completed }

/// The colored pill naming a reminder's status, always word-and-color
/// together (CLAUDE.md — never color alone).
class ReminderStatusPill extends StatelessWidget {
  const ReminderStatusPill({required this.status, super.key});

  final ReminderStatusKind status;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    final (background, foreground, label) = switch (status) {
      ReminderStatusKind.upcoming => (
        colors.surfaceTeal,
        colors.brandPrimary,
        strings.reminderStatusUpcoming,
      ),
      ReminderStatusKind.missed => (
        colors.errorTint,
        colors.error,
        strings.reminderStatusMissed,
      ),
      ReminderStatusKind.completed => (
        colors.successTint,
        colors.successInk,
        strings.reminderStatusCompleted,
      ),
    };

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _paddingH,
            vertical: _paddingV,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: _fontSize,
              fontWeight: AppTypography.bold,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
