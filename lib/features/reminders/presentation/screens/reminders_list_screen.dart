import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/reminders_cubit.dart';
import '../cubit/reminders_state.dart';
import '../widgets/reminder_list_item.dart';

// From `Waraqti.dc.html` → `isReminders`. Mirrors the documents list's own
// page padding (top already accounts for the status bar SafeArea applies;
// bottom clears the translucent nav bar).
const double _pageTop = 64 - 52;
const double _pageSide = 20;
const double _pageBottom = 108;
const double _headerGapBelow = 16;
const double _tabsGapBelow = 20;
const double _rowGap = 12;
const double _addIconSize = 16;

/// The «التذكيرات» tab: every reminder, bucketed into القادمة/الفائتة/المكتملة
/// (F09-T11).
///
/// The header stays on screen through every state, same as
/// `DocumentsListScreen` — only the tabs and the list body below swap
/// between loading, a bucket's rows, and a failed read.
class RemindersListScreen extends StatelessWidget {
  const RemindersListScreen({
    this.onAddReminder,
    this.onOpenReminder,
    super.key,
  });

  /// Opens the manual create flow. `null` leaves the header/empty-state
  /// button un-tappable, so the screen still pumps on its own in a test.
  final VoidCallback? onAddReminder;

  /// Opens one reminder's details (F09-T12), given its id. `null` leaves
  /// every card un-tappable.
  final ValueChanged<String>? onOpenReminder;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: _pageTop),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _pageSide),
                child: _Header(onAddReminder: onAddReminder),
              ),
              const SizedBox(height: _headerGapBelow),
              Expanded(
                child: BlocBuilder<RemindersCubit, RemindersState>(
                  builder: (context, state) => _Content(
                    state: state,
                    onAddReminder: onAddReminder,
                    onOpenReminder: onOpenReminder,
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

class _Header extends StatelessWidget {
  const _Header({this.onAddReminder});

  final VoidCallback? onAddReminder;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    // `Wrap`, not `Row`: at large text scale the button's own label can grow
    // wider than the space a fixed-size sibling would leave it, which a
    // `Row` has no way to resolve short of overflowing. Wrapping the button
    // onto its own line under the title costs nothing here — there is
    // nothing else on the page for it to collide with.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.reminderListTitle,
            style: AppTypography.headlineLarge.copyWith(color: colors.ink),
          ),
        ),
        FilledButton.icon(
          onPressed: onAddReminder,
          icon: StrokeIcon(
            StrokeGlyph.plus,
            color: colors.onBrand,
            size: _addIconSize,
            strokeWidth: 2.2,
          ),
          label: Text(strings.reminderAddAction),
          style: FilledButton.styleFrom(
            backgroundColor: colors.brandPrimary,
            foregroundColor: colors.onBrand,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 11,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            textStyle: AppTypography.labelMedium.copyWith(
              fontWeight: AppTypography.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    this.onAddReminder,
    this.onOpenReminder,
  });

  final RemindersState state;
  final VoidCallback? onAddReminder;
  final ValueChanged<String>? onOpenReminder;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      RemindersLoading() => const _Loading(),
      RemindersUnavailable() => const _LoadFailed(),
      RemindersAvailable(:final tab, :final hasNoReminders, :final visible) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pageSide),
              child: _Tabs(selected: tab),
            ),
            const SizedBox(height: _tabsGapBelow),
            Expanded(
              child: hasNoReminders
                  ? _EmptyLibrary(onAddReminder: onAddReminder)
                  : visible.isEmpty
                  ? _EmptyBucket(tab: tab)
                  : _List(reminders: visible, onOpenReminder: onOpenReminder),
            ),
          ],
        ),
    };
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected});

  final RemindersTab selected;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    final tabs = [
      (RemindersTab.upcoming, strings.reminderTabUpcoming),
      (RemindersTab.missed, strings.reminderTabMissed),
      (RemindersTab.completed, strings.reminderTabCompleted),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (tab, label) in tabs)
              Expanded(
                child: _TabButton(
                  label: label,
                  selected: tab == selected,
                  onTap: () => context.read<RemindersCubit>().setTab(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 13.5,
                fontWeight: AppTypography.bold,
                color: selected ? colors.brandPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.reminders, this.onOpenReminder});

  final List<Reminder> reminders;
  final ValueChanged<String>? onOpenReminder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(_pageSide, 0, _pageSide, _pageBottom),
      itemCount: reminders.length,
      separatorBuilder: (context, index) => const SizedBox(height: _rowGap),
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return ReminderListItem(
          reminder: reminder,
          onTap: onOpenReminder == null
              ? null
              : () => onOpenReminder!(reminder.id),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.onAddReminder});

  final VoidCallback? onAddReminder;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return _EmptyState(
      glyph: StrokeGlyph.navReminders,
      title: strings.reminderEmptyTitle,
      subtitle: strings.reminderEmptySubtitle,
      ctaLabel: strings.reminderAddAction,
      onCta: onAddReminder,
    );
  }
}

/// A tab with no rows while the library itself is not empty — «الفائتة» or
/// «المكتملة» with nothing (yet) in them. Simpler than [_EmptyLibrary]: no
/// call to action, since there is nothing to *do* about having missed or
/// completed nothing.
class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket({required this.tab});

  final RemindersTab tab;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return switch (tab) {
      RemindersTab.missed => _EmptyState(
        glyph: StrokeGlyph.clock,
        title: strings.reminderEmptyMissedTitle,
      ),
      RemindersTab.completed => _EmptyState(
        glyph: StrokeGlyph.check,
        title: strings.reminderEmptyCompletedTitle,
      ),
      // A non-empty library's «القادمة» bucket is only empty when every
      // reminder has already been missed or completed — still nothing to do
      // about from here.
      RemindersTab.upcoming => _EmptyState(
        glyph: StrokeGlyph.navReminders,
        title: strings.reminderEmptyTitle,
      ),
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.glyph,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  final StrokeGlyph glyph;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        56,
        AppSpacing.xl,
        _pageBottom,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceTeal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: StrokeIcon(glyph, color: colors.brandPrimary, size: 32),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: AppTypography.extraBold,
              color: colors.textBody,
            ),
          ),
          if (subtitle case final text?) ...[
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textCaption,
                fontWeight: AppTypography.medium,
              ),
            ),
          ],
          if (ctaLabel case final label?) ...[
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onCta,
              style: FilledButton.styleFrom(
                backgroundColor: colors.brandPrimary,
                foregroundColor: colors.onBrand,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                textStyle: AppTypography.labelLarge,
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.light.brandPrimary,
        semanticsLabel: context.strings.stateLoading,
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Center(
        child: Text(
          context.strings.reminderListErrorTitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: colors.textBody),
        ),
      ),
    );
  }
}
