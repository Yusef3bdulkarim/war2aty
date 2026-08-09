import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/reminder_form_cubit.dart';
import '../cubit/reminder_form_state.dart';
import '../widgets/reminder_alert_list_section.dart';
import '../widgets/reminder_event_info_card.dart';
import '../widgets/reminder_linked_document_row.dart';
import '../widgets/reminder_text_field.dart';

// From `Waraqti.dc.html` → `reminderCreate` / `manualReminder`, which share
// this exact layout (F09-T02): a plain top bar, the form, a pinned save bar.
const double _topBarTop = 56 - 52;
const double _topBarBottom = 12;
const double _topBarSide = AppSpacing.screenHorizontal;
const double _topBarGap = 8;
const double _topBarButton = 40;
const double _pageSide = 18;
const double _pageTop = 18;
const double _pageBottom = 20;
const double _bottomBarSide = 16;
const double _bottomBarTop = 12;
const double _bottomBarBottom = 28;
const double _saveButtonHeight = 54;
const double _saveButtonRadius = 15;
const double _saveButtonFontSize = 17;
const double _cancelButtonHeight = 44;
const double _cancelButtonFontSize = 15;
const double _cancelButtonGapAbove = 2;

/// The reminder form's screen chrome — top bar, scrollable body, pinned save
/// bar — shared by create-from-document (F09-T03) and create-manual
/// (F09-T04). What appears *inside* the body differs ([manualFields]/
/// [readOnlyEventInfo]); the frame around it does not.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({
    required this.screenTitle,
    this.onSaved,
    this.onClose,
    super.key,
  });

  final String screenTitle;

  /// The reminder was written. The router pushes the success screen with it.
  final ValueChanged<Reminder>? onSaved;

  final VoidCallback? onClose;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final state = context.read<ReminderFormCubit>().state;
    final editing = state is ReminderFormEditing ? state : null;
    _titleController = TextEditingController(text: editing?.title ?? '');
    _noteController = TextEditingController(text: editing?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return BlocConsumer<ReminderFormCubit, ReminderFormState>(
      listenWhen: (_, state) => state is ReminderFormSaved,
      listener: (context, state) {
        if (state is ReminderFormSaved) widget.onSaved?.call(state.reminder);
      },
      builder: (context, state) {
        final editing = switch (state) {
          ReminderFormEditing() => state,
          ReminderFormSaveFailed(:final editing) => editing,
          // The listener above navigates away the same frame; nothing here
          // is shown long enough to matter.
          ReminderFormSaved() => null,
        };

        return Scaffold(
          backgroundColor: colors.surface,
          body: editing == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    _TopBar(title: widget.screenTitle, onClose: widget.onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          _pageSide,
                          _pageTop,
                          _pageSide,
                          _pageBottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ReminderTextField(
                              label: context.strings.reminderFormTitleLabel,
                              controller: _titleController,
                              required: editing.isManual,
                              onChanged: context
                                  .read<ReminderFormCubit>()
                                  .setTitle,
                            ),
                            // A from-document reminder's event date/time are
                            // fixed and shown read-only; a manual reminder's
                            // own date/time picker is built in F09-T04.
                            if (!editing.isManual && editing.eventDate != null)
                              ReminderEventInfoCard(
                                eventDate: editing.eventDate!,
                                eventMinuteOfDay: editing.eventMinuteOfDay,
                              ),
                            ReminderAlertListSection(
                              alerts: editing.alerts,
                              eventInstant: editing.eventInstant,
                              onAdd: context.read<ReminderFormCubit>().addAlert,
                              onRemove: context
                                  .read<ReminderFormCubit>()
                                  .removeAlertAt,
                            ),
                            ReminderTextField(
                              label: context.strings.reminderNoteLabel,
                              hint: context.strings.reminderNoteHint,
                              controller: _noteController,
                              minLines: 3,
                              maxLines: 6,
                              onChanged: context
                                  .read<ReminderFormCubit>()
                                  .setDescription,
                            ),
                            if (editing.documentTitle case final title?)
                              ReminderLinkedDocumentRow(documentTitle: title),
                          ],
                        ),
                      ),
                    ),
                    _SaveBar(editing: editing, onClose: widget.onClose),
                  ],
                ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
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
              SizedBox.square(
                dimension: _topBarButton,
                child: IconButton(
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  tooltip: strings.actionBack,
                  icon: Transform.flip(
                    flipX: mirror,
                    child: StrokeIcon(
                      StrokeGlyph.arrowBack,
                      color: colors.ink,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelCard.copyWith(
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              const SizedBox.square(dimension: _topBarButton),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.editing, this.onClose});

  final ReminderFormEditing editing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _bottomBarSide,
            _bottomBarTop,
            _bottomBarSide,
            _bottomBarBottom,
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: _saveButtonHeight,
                child: FilledButton(
                  onPressed: editing.canSave
                      ? context.read<ReminderFormCubit>().save
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brandPrimary,
                    foregroundColor: colors.onBrand,
                    disabledBackgroundColor: colors.borderSoft,
                    disabledForegroundColor: colors.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_saveButtonRadius),
                    ),
                    textStyle: AppTypography.labelMedium.copyWith(
                      fontSize: _saveButtonFontSize,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  child: editing.isSaving
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colors.onBrand,
                          ),
                        )
                      : Text(strings.reminderSaveAction),
                ),
              ),
              const SizedBox(height: _cancelButtonGapAbove),
              SizedBox(
                width: double.infinity,
                height: _cancelButtonHeight,
                child: TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    textStyle: AppTypography.labelMedium.copyWith(
                      fontSize: _cancelButtonFontSize,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  child: Text(strings.actionCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
