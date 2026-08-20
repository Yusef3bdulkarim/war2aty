import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/cairo_day.dart';
import '../../../../core/time/document_date_label.dart';
import '../../../../core/widgets/service_state_view.dart';
import '../../../../core/widgets/top_bar_icon_button.dart';
import '../cubit/reminder_details_cubit.dart';
import '../cubit/reminder_details_state.dart';
import '../widgets/delete_reminder_sheet.dart';
import '../widgets/reminder_status_pill.dart';
import '../widgets/snooze_sheet.dart';

// From `Waraqti.dc.html` → `isReminderDetails`.
const double _topBarTop = 56 - 52;
const double _topBarBottom = 12;
const double _topBarSide = AppSpacing.screenHorizontal;
const double _topBarGap = 8;
const double _pageSide = 18;
const double _pageTop = 18;
const double _pageBottom = 32;
const double _titleFontSize = 21;
const double _titleGapBelow = 16;
const double _rowGap = 14;
const double _rowIconSize = 17;
const double _rowGapInner = 10;
const double _rowFontSize = 14.5;
const double _rowLabelWidth = 96;
const double _cardRadius = AppRadii.lg;
const double _cardPadding = 16;
const double _sectionGapAbove = 22;
const double _linkedDocGapAbove = 10;
const double _actionsGapAbove = 26;
const double _actionGap = 10;
const double _actionHeight = 52;
const double _actionRadius = AppRadii.md;

/// «تفاصيل التذكير» (F09-T12) — one reminder's full record, with the actions
/// the list card only offers a shortcut to: complete, snooze, delete.
///
/// Mirrors [DocumentDetailsScreen]'s own shape: a fixed top bar, a scrollable
/// body driven entirely by the cubit's state, and every write followed by a
/// snackbar rather than a silent success.
class ReminderDetailsScreen extends StatelessWidget {
  const ReminderDetailsScreen({this.onClose, this.onOpenDocument, super.key});

  /// Leaves the details screen. The router supplies it; optional so the
  /// screen can be pumped on its own in a widget test.
  final VoidCallback? onClose;

  /// Opens the linked document's own details screen, given its id. `null`
  /// leaves the linked-document row un-tappable.
  final ValueChanged<String>? onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: BlocBuilder<ReminderDetailsCubit, ReminderDetailsState>(
        builder: (context, state) => switch (state) {
          ReminderDetailsLoading() => const _Loading(),
          ReminderDetailsAvailable(
            :final reminder,
            :final linkedDocumentTitle,
          ) =>
            _DetailsBody(
              reminder: reminder,
              linkedDocumentTitle: linkedDocumentTitle,
              onClose: onClose,
              onOpenDocument: onOpenDocument,
            ),
          ReminderDetailsNotFound() => _StateBody(
            glyph: StrokeGlyph.search,
            tint: colors.surfaceAlt,
            iconColor: colors.textMuted,
            title: context.strings.reminderDetailsNotFoundTitle,
            message: context.strings.reminderDetailsNotFoundMessage,
            onClose: onClose,
          ),
          ReminderDetailsUnavailable() => _StateBody(
            glyph: StrokeGlyph.warningTriangle,
            tint: colors.warningTint,
            iconColor: colors.warning,
            title: context.strings.reminderDetailsErrorTitle,
            message: context.strings.reminderDetailsErrorMessage,
            onClose: onClose,
          ),
        },
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

/// The reminder is gone, or could not be read — one layout, two sets of
/// words, the same shape `DocumentDetailsScreen`'s own pair uses.
class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.glyph,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.message,
    this.onClose,
  });

  final StrokeGlyph glyph;
  final Color tint;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ServiceStateView(
      glyph: glyph,
      tint: tint,
      iconColor: iconColor,
      title: title,
      message: message,
      primary: ServiceStateAction(
        label: strings.reminderDetailsBackToList,
        onPressed: onClose ?? () {},
      ),
      onBack: onClose,
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.reminder,
    required this.linkedDocumentTitle,
    this.onClose,
    this.onOpenDocument,
  });

  final Reminder reminder;
  final String? linkedDocumentTitle;
  final VoidCallback? onClose;
  final ValueChanged<String>? onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(onClose: onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _pageSide,
              _pageTop,
              _pageSide,
              _pageBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusAndTitle(reminder: reminder),
                const SizedBox(height: _titleGapBelow),
                _InfoCard(reminder: reminder),
                if (reminder.description case final note? when note.isNotEmpty)
                  _DescriptionCard(note: note),
                if (reminder.documentId case final documentId?) ...[
                  const SizedBox(height: _linkedDocGapAbove),
                  _LinkedDocumentButton(
                    documentId: documentId,
                    title: linkedDocumentTitle,
                    onTap: onOpenDocument,
                  ),
                ],
                const SizedBox(height: _actionsGapAbove),
                _Actions(reminder: reminder, onDeleted: onClose),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _topBarSide,
            _topBarTop,
            _topBarSide,
            _topBarBottom,
          ),
          child: Row(
            children: [
              TopBarIconButton(
                onPressed: onClose,
                tooltip: strings.analysisResultBackLabel,
                icon: Transform.flip(
                  flipX: mirror,
                  child: StrokeIcon(
                    StrokeGlyph.arrowBack,
                    color: colors.ink,
                    strokeWidth: 2,
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.reminderDetailsTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelCard.copyWith(
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              // Balances the back button so the title stays centred, the
              // same trick `DocumentDetailsScreen`'s overflow menu slot does
              // — this screen just has nothing to put there.
              const SizedBox(width: TopBarIconButton.dimension),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusAndTitle extends StatelessWidget {
  const _StatusAndTitle({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReminderStatusPill(status: _pillStatus(reminder)),
        const SizedBox(height: 10),
        Text(
          reminder.title,
          style: AppTypography.headlineMedium.copyWith(
            fontSize: _titleFontSize,
            fontWeight: AppTypography.extraBold,
            color: colors.ink,
          ),
        ),
      ],
    );
  }
}

ReminderStatusKind _pillStatus(Reminder reminder) {
  if (reminder.status.isCompleted) return ReminderStatusKind.completed;
  if (reminder.isOverdue()) return ReminderStatusKind.missed;
  return ReminderStatusKind.upcoming;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final alert = reminder.nextAlert;
    // DST-aware, matching how the alert was scheduled — see
    // `formatClockTime`'s doc for why not `cairoLocalOf`.
    final localAlert = alert == null
        ? null
        : cairoWallClockOf(alert.scheduledAt);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          children: [
            _InfoRow(
              glyph: StrokeGlyph.calendar,
              label: strings.reminderDetailsDateLabel,
              value: formatDocumentDate(strings, reminder.eventDate),
            ),
            const SizedBox(height: _rowGap),
            _InfoRow(
              glyph: StrokeGlyph.clock,
              label: strings.reminderDetailsTimeLabel,
              value: reminder.hasEventTime
                  ? formatWallClockTime(
                      strings,
                      reminder.eventMinuteOfDay! ~/ 60,
                      reminder.eventMinuteOfDay! % 60,
                    )
                  : strings.reminderEventTimeMissing,
            ),
            if (localAlert != null) ...[
              const SizedBox(height: _rowGap),
              _InfoRow(
                glyph: StrokeGlyph.clock,
                label: strings.reminderDetailsAlertLabel,
                value:
                    '${formatDocumentDate(strings, localAlert)}'
                    ' — ${formatWallClockTime(strings, localAlert.hour, localAlert.minute)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.glyph,
    required this.label,
    required this.value,
  });

  final StrokeGlyph glyph;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StrokeIcon(glyph, color: colors.iconMuted, size: _rowIconSize),
        const SizedBox(width: _rowGapInner),
        SizedBox(
          width: _rowLabelWidth,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: _rowFontSize,
              fontWeight: AppTypography.semiBold,
              color: colors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              fontSize: _rowFontSize,
              fontWeight: AppTypography.bold,
              color: colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.only(top: _sectionGapAbove),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.reminderDetailsDescriptionLabel,
                style: AppTypography.caption.copyWith(
                  fontSize: _rowFontSize,
                  fontWeight: AppTypography.bold,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                note,
                style: AppTypography.bodySmall.copyWith(color: colors.textBody),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedDocumentButton extends StatelessWidget {
  const _LinkedDocumentButton({
    required this.documentId,
    required this.title,
    this.onTap,
  });

  final String documentId;

  /// `null` while the document read is in flight, or once the linked
  /// document has been deleted — the button still shows, but with no title
  /// to name, and stays tappable so a stale link still resolves to whatever
  /// the document screen itself decides to show for it.
  final String? title;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return Material(
      color: colors.surfaceTeal,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(documentId),
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: Row(
            children: [
              StrokeIcon(
                StrokeGlyph.documentCheck,
                color: colors.brandPrimary,
                size: _rowIconSize,
              ),
              const SizedBox(width: _rowGapInner),
              Expanded(
                child: Text(
                  title ?? strings.reminderDetailsLinkedDocumentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: _rowFontSize,
                    fontWeight: AppTypography.bold,
                    color: colors.brandPrimary,
                  ),
                ),
              ),
              Transform.flip(
                flipX: mirror,
                child: StrokeIcon(
                  StrokeGlyph.chevronForward,
                  color: colors.brandPrimary,
                  size: _rowIconSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «تم التنفيذ»/«تأجيل», shown only while pending — the same rule
/// [ReminderListItem] applies — plus «حذف», always available.
class _Actions extends StatelessWidget {
  const _Actions({required this.reminder, this.onDeleted});

  final Reminder reminder;

  /// Leaves the details screen after a successful delete — the router's own
  /// [onClose], reused rather than a fresh navigation of its own.
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final cubit = context.read<ReminderDetailsCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reminder.status.isPending) ...[
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: strings.reminderDetailsCompleteAction,
                  background: colors.success,
                  foreground: colors.onBrand,
                  onTap: () => _complete(context, cubit, strings),
                ),
              ),
              const SizedBox(width: _actionGap),
              Expanded(
                child: _ActionButton(
                  label: strings.reminderDetailsSnoozeAction,
                  background: colors.surfaceTeal,
                  foreground: colors.brandPrimary,
                  onTap: () => _snooze(context, cubit, strings),
                ),
              ),
            ],
          ),
          const SizedBox(height: _actionGap),
        ],
        SizedBox(
          height: _actionHeight,
          child: OutlinedButton(
            onPressed: () => _delete(context, cubit, strings),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_actionRadius),
              ),
              textStyle: AppTypography.labelLarge,
            ),
            child: Text(strings.reminderDetailsDeleteAction),
          ),
        ),
      ],
    );
  }

  Future<void> _complete(
    BuildContext context,
    ReminderDetailsCubit cubit,
    AppStrings strings,
  ) async {
    final ok = await cubit.complete();
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok
          ? strings.reminderCompletedFeedback
          : strings.reminderActionFailedFeedback,
    );
  }

  Future<void> _snooze(
    BuildContext context,
    ReminderDetailsCubit cubit,
    AppStrings strings,
  ) async {
    final newAlertTime = await pickReminderSnoozeTime(context);
    if (newAlertTime == null || !context.mounted) return;

    final ok = await cubit.snooze(newAlertTime);
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok
          ? strings.reminderSnoozedFeedback
          : strings.reminderActionFailedFeedback,
    );
  }

  Future<void> _delete(
    BuildContext context,
    ReminderDetailsCubit cubit,
    AppStrings strings,
  ) async {
    final confirmed = await showDeleteReminderSheet(context);
    if (!confirmed || !context.mounted) return;

    final ok = await cubit.delete();
    if (!context.mounted) return;
    if (ok) {
      _showFeedback(context, strings.reminderDeletedFeedback);
      // The watcher would eventually show "not found" on its own once the
      // delete lands, but leaving immediately is what the user expects —
      // the same convention `DocumentDetailsScreen`'s own delete follows.
      onDeleted?.call();
    } else {
      _showFeedback(context, strings.reminderActionFailedFeedback);
    }
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        // A minimum, not a fixed, height — Large Text needs more room than
        // this to draw the label without clipping, and the button is free
        // to take it. Matches `reminder_list_item.dart`'s `_ActionChip`,
        // which draws the same two labels.
        minimumSize: const Size(0, _actionHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_actionRadius),
        ),
        textStyle: AppTypography.labelLarge,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
