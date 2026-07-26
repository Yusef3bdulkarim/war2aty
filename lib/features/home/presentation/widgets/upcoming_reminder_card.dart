import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/reminder_due_label.dart';
import '../../../../core/reminders/upcoming_reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/skeleton.dart';
import '../cubit/home_state.dart';

// From `Waraqti.dc.html` → `home`.
const double _sectionGapAbove = 26;
const double _headerGap = 11;
const double _cardPadding = 18;
const double _cardGap = 14;
const double _iconBox = 46;
const double _edgeStripe = 4;

/// "Coming up" — the single next reminder.
///
/// Hidden until one is scheduled; Home's own empty state (F02-T09) covers the
/// nothing-yet case for the whole screen.
class UpcomingReminderCard extends StatelessWidget {
  const UpcomingReminderCard({
    required this.section,
    this.onOpen,
    this.now,
    super.key,
  });

  final ReminderSection section;

  /// Opens the reminder's details (F09); null until that screen exists.
  final ValueChanged<UpcomingReminder>? onOpen;

  /// Fixed "current time", for deterministic tests.
  final DateTime? now;

  /// The reminder to draw, or `null` when the section stays hidden.
  static UpcomingReminder? _reminderToShow(ReminderSection section) =>
      switch (section) {
        ReminderLoading() || ReminderUnavailable() => null,
        ReminderAvailable(:final reminder) => reminder,
      };

  /// Whether this section renders anything at all.
  static bool isVisible(ReminderSection section) =>
      _reminderToShow(section) != null;

  @override
  Widget build(BuildContext context) {
    if (section is ReminderLoading) return const _ReminderSkeleton();

    final reminder = _reminderToShow(section);
    if (reminder == null) return const SizedBox.shrink();

    final s = context.strings;
    const colors = AppColors.light;
    final due = reminderDueLabel(s, reminder.dueAt, now: now);
    final radius = BorderRadius.circular(AppRadii.xl);

    return Padding(
      padding: const EdgeInsets.only(top: _sectionGapAbove),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              s.homeUpcomingReminderTitle,
              style: AppTypography.caption.copyWith(
                color: colors.textMuted,
                fontWeight: AppTypography.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: _headerGap),
          Semantics(
            button: onOpen != null,
            label: '${reminder.title}. $due',
            onTap: onOpen == null ? null : () => onOpen!(reminder),
            excludeSemantics: true,
            child: Material(
              color: colors.card,
              borderRadius: radius,
              child: InkWell(
                onTap: onOpen == null ? null : () => onOpen!(reminder),
                borderRadius: radius,
                child: Ink(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: radius,
                    // The design's `border-right: 4px solid` — in an RTL page
                    // that is the *leading* edge, so it is expressed
                    // directionally and flips to the left in English.
                    border: BorderDirectional(
                      start: BorderSide(
                        color: colors.brandPrimary,
                        width: _edgeStripe,
                      ),
                    ),
                    boxShadow: AppShadows.card,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_cardPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: _iconBox,
                          height: _iconBox,
                          decoration: BoxDecoration(
                            color: colors.surfaceTealAlt,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Center(
                            child: StrokeIcon(
                              StrokeGlyph.navReminders,
                              color: colors.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: _cardGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reminder.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 16,
                                  color: colors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                due,
                                // Amber, because a due date is the thing the
                                // user has to act on — paired with wording,
                                // never colour alone.
                                style: AppTypography.caption.copyWith(
                                  fontSize: 13.5,
                                  color: colors.warning,
                                  fontWeight: AppTypography.semiBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onOpen != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            s.actionView,
                            style: AppTypography.caption.copyWith(
                              fontSize: 13,
                              color: colors.brandPrimary,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's silhouette while the database is being read.
///
/// Mirrors the real card's measurements so content does not jump into place
/// when it arrives.
class _ReminderSkeleton extends StatelessWidget {
  const _ReminderSkeleton();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.only(top: _sectionGapAbove),
      child: Shimmer(
        label: context.strings.stateLoading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 72, height: 13),
            const SizedBox(height: _headerGap),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: const Padding(
                padding: EdgeInsets.all(_cardPadding),
                child: Row(
                  children: [
                    SkeletonBox(
                      width: _iconBox,
                      height: _iconBox,
                      radius: AppRadii.md,
                    ),
                    SizedBox(width: _cardGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 16),
                          SizedBox(height: 8),
                          SkeletonBox(width: 140, height: 13),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
