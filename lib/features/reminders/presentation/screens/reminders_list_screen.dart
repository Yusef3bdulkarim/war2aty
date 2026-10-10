import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/quick_reminder_date.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/reminders_cubit.dart';
import '../cubit/reminders_state.dart';
import '../models/manual_reminder_seed.dart';
import '../widgets/reminder_list_item.dart';
import '../widgets/reminders_empty_art.dart';
import '../widgets/reminders_quick_create.dart';
import '../widgets/snooze_sheet.dart';

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

// The empty library's own pane (F29, concept D's `.pane > .inner`). Its
// content starts 24 px under the header — top-anchored, not centred, because
// centring pushes the first quick row below the fold on a small phone at
// 1.6× text — and [_headerGapBelow] has already provided part of that.
const double _emptyTopGap = 24 - _headerGapBelow;
const double _emptyArtGapBelow = 16;
const double _emptyTitleGapBelow = 10;
const double _emptyKickerGapAbove = 22;
const double _emptyKickerGapBelow = 10;
const double _emptyScanGapAbove = 14;
const double _emptyHintGapAbove = 10;
const double _emptyTitleFontSize = 18;
const double _emptyKickerFontSize = 13.5;
const double _emptyHintFontSize = 12.8;
const double _emptyScanIconSize = 18;
const double _emptyScanPaddingV = 13;

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
    this.onQuickReminder,
    this.onScan,
    super.key,
  });

  /// Opens the manual create flow. `null` leaves the header/empty-state
  /// button un-tappable, so the screen still pumps on its own in a test.
  final VoidCallback? onAddReminder;

  /// Opens one reminder's details (F09-T12), given its id. `null` leaves
  /// every card un-tappable.
  final ValueChanged<String>? onOpenReminder;

  /// Opens the same manual create flow with a date and time already in it —
  /// one of the empty state's three quick dates (F29). The screen hands over
  /// a [ManualReminderSeed] rather than a route, so it still knows nothing
  /// about `go_router`.
  final ValueChanged<ManualReminderSeed>? onQuickReminder;

  /// Opens the capture flow from the empty state's «صوّر ورقة» (F29). While
  /// `null` the action is not drawn at all, the way «مستنداتي»'s own empty
  /// state drops its CTA when it has nowhere to send the user — T11 wires
  /// this to the camera.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
                    onOpenReminder: onOpenReminder,
                    onQuickReminder: onQuickReminder,
                    onScan: onScan,
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
    final colors = AppColors.of(context);
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
    this.onOpenReminder,
    this.onQuickReminder,
    this.onScan,
  });

  final RemindersState state;
  final ValueChanged<String>? onOpenReminder;
  final ValueChanged<ManualReminderSeed>? onQuickReminder;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      RemindersLoading() => const _Loading(),
      RemindersUnavailable() => const _LoadFailed(),
      // Nothing saved at all: the tabs come off with the list. Three tabs
      // that each lead to the same nothing are the main reason the screen
      // used to read as broken, and the state below them now carries its own
      // way in (F29, locked decision 5). They stay for a single *empty
      // bucket*, which a user does need a way back out of.
      RemindersAvailable(hasNoReminders: true) => _EmptyLibrary(
        onQuickReminder: onQuickReminder,
        onScan: onScan,
      ),
      RemindersAvailable(:final tab, :final visible) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pageSide),
            child: _Tabs(selected: tab),
          ),
          const SizedBox(height: _tabsGapBelow),
          Expanded(
            child: visible.isEmpty
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
    final colors = AppColors.of(context);
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
    final colors = AppColors.of(context);

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
          onComplete: () => _complete(context, reminder.id),
          onSnooze: () => _snooze(context, reminder.id),
        );
      },
    );
  }

  Future<void> _complete(BuildContext context, String id) async {
    final cubit = context.read<RemindersCubit>();
    final strings = context.strings;
    final ok = await cubit.complete(id);
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok
          ? strings.reminderCompletedFeedback
          : strings.reminderActionFailedFeedback,
    );
  }

  Future<void> _snooze(BuildContext context, String id) async {
    final cubit = context.read<RemindersCubit>();
    final strings = context.strings;

    final newAlertTime = await pickReminderSnoozeTime(context);
    if (newAlertTime == null || !context.mounted) return;

    final ok = await cubit.snooze(id, newAlertTime);
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok
          ? strings.reminderSnoozedFeedback
          : strings.reminderActionFailedFeedback,
    );
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// «التذكيرات» with nothing in it at all — the screen F29 exists to fix.
///
/// It used to be a centred title and one grey line 80 px down an otherwise
/// blank page. Now the middle of the screen does something: the illustration,
/// the title and its promise, then the three ready-made dates, the «صوّر
/// ورقة» way in, and a line pointing back at the header's «إضافة تذكير» for a
/// reminder entered from scratch (F29, concept D).
///
/// Top-anchored and scrolling in its own pane, rather than centred: centring
/// pushes the first quick row under the fold on a small phone at 1.6× text,
/// and the quick rows are the whole point (locked decision 6).
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.onQuickReminder, this.onScan});

  final ValueChanged<ManualReminderSeed>? onQuickReminder;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        _pageSide,
        _emptyTopGap,
        _pageSide,
        _pageBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: RemindersEmptyArt()),
          const SizedBox(height: _emptyArtGapBelow),
          Text(
            strings.reminderEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: _emptyTitleFontSize,
              fontWeight: AppTypography.extraBold,
              color: colors.textBody,
            ),
          ),
          const SizedBox(height: _emptyTitleGapBelow),
          Text(
            strings.reminderEmptySubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textCaption,
              fontWeight: AppTypography.medium,
            ),
          ),
          const SizedBox(height: _emptyKickerGapAbove),
          // Start-aligned, unlike everything above it: it labels the rows
          // underneath rather than addressing the user, so it lines up with
          // their leading edge.
          Text(
            strings.reminderQuickCreateKicker,
            style: AppTypography.caption.copyWith(
              fontSize: _emptyKickerFontSize,
              fontWeight: AppTypography.extraBold,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: _emptyKickerGapBelow),
          RemindersQuickCreate(
            // One clock read per build of this state, in the only place that
            // knows the dates are about to be shown. A rebuild after
            // midnight correctly re-reads them.
            slots: quickReminderSlots(),
            onSelected: (slot) => onQuickReminder?.call(
              ManualReminderSeed(
                eventDate: slot.eventDate,
                eventMinuteOfDay: slot.eventMinuteOfDay,
              ),
            ),
          ),
          if (onScan case final scan?) ...[
            const SizedBox(height: _emptyScanGapAbove),
            FilledButton.icon(
              onPressed: scan,
              icon: StrokeIcon(
                StrokeGlyph.camera,
                color: colors.brandPrimary,
                size: _emptyScanIconSize,
              ),
              label: Text(strings.reminderEmptyScanCta),
              style: FilledButton.styleFrom(
                backgroundColor: colors.surfaceTeal,
                foregroundColor: colors.brandPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: _emptyScanPaddingV,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  side: BorderSide(color: colors.borderCool),
                ),
                textStyle: AppTypography.labelLarge.copyWith(fontSize: 15.5),
              ),
            ),
            const SizedBox(height: _emptyHintGapAbove),
          ] else
            const SizedBox(height: _emptyScanGapAbove),
          // The one place the header's button is named in the body: the
          // empty state deliberately does not repeat it, so this sentence
          // points at it instead.
          Text(
            strings.reminderEmptyScanHint,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontSize: _emptyHintFontSize,
              fontWeight: AppTypography.medium,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
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
        title: strings.reminderEmptyMissedTitle,
      ),
      RemindersTab.completed => _EmptyState(
        title: strings.reminderEmptyCompletedTitle,
      ),
      // A non-empty library's «القادمة» bucket is only empty when every
      // reminder has already been missed or completed — still nothing to do
      // about from here.
      RemindersTab.upcoming => _EmptyState(title: strings.reminderEmptyTitle),
    };
  }
}

/// The minimal placeholder an empty *bucket* still uses — one centred title,
/// 80 px down.
///
/// This is what the wholly-empty library looked like until F29-T09 replaced
/// it, and F29-T10 replaces it here too: «الفائتة» and «المكتملة» get the
/// same visual vocabulary as [_EmptyLibrary], plus a way back to «القادمة».
/// Its subtitle slot came off with the library's own use of it, since the
/// buckets' subtitles arrive with that redesign.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        80,
        AppSpacing.xl,
        _pageBottom,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: AppTypography.extraBold,
              color: colors.textBody,
            ),
          ),
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
        color: AppColors.of(context).brandPrimary,
        semanticsLabel: context.strings.stateLoading,
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
