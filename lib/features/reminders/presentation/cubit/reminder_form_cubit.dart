import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/permissions/usecases/get_notification_permission.dart';
import '../../../../core/permissions/usecases/request_notification_permission.dart';
import '../../../../core/reminders/alert_time_offset.dart';
import '../../../../core/reminders/usecases/create_manual_reminder.dart';
import '../../../../core/reminders/usecases/create_reminder_from_document_date.dart';
import '../../../../core/time/cairo_day.dart';
import '../models/reminder_alert_draft.dart';
import '../models/reminder_from_document_args.dart';
import 'reminder_form_state.dart';

/// The `get_it` instance name the manual-reminder [ReminderFormCubit] is
/// registered under — a plain factory would collide with the
/// from-document one's `registerFactoryParam` on the same type, so the two
/// are told apart by name instead (`service_locator.dart`,
/// `app_router.dart`).
const String manualReminderFormInstanceName = 'manualReminderForm';

/// Drives both reminder forms (F09-T02): create-from-a-document's-date
/// (F09-T03) and create-manually (F09-T04). One cubit rather than two
/// near-identical ones — the fields, the alert list (F09-T05/T06/T08) and the
/// save step are exactly the same logic either way; only where the event
/// date/time come from differs, and that is decided once, at construction.
///
/// Depends on its use cases only (architecture rule); it never sees
/// `RemindersRepository`.
final class ReminderFormCubit extends Cubit<ReminderFormState> {
  /// A reminder about a date the analysis already found — the event date and
  /// time are fixed from [args] and never change from here.
  ReminderFormCubit.fromDocument({
    required CreateReminderFromDocumentDate createFromDocumentDate,
    required CreateManualReminder createManual,
    required GetNotificationPermission getNotificationPermission,
    required RequestNotificationPermission requestNotificationPermission,
    required ReminderFromDocumentArgs args,
  }) : _createFromDocumentDate = createFromDocumentDate,
       _createManual = createManual,
       _getNotificationPermission = getNotificationPermission,
       _requestNotificationPermission = requestNotificationPermission,
       super(
         ReminderFormEditing(
           title: args.title,
           eventDate: args.eventDate,
           eventMinuteOfDay: args.eventMinuteOfDay,
           documentId: args.documentId,
           documentTitle: args.documentTitle,
           isManual: false,
           alerts: _defaultAlertsFor(args.eventDate, args.eventMinuteOfDay),
         ),
       );

  /// A reminder entered by hand — every field starts empty; the user fills
  /// in the title, date, time and alerts themselves.
  ReminderFormCubit.manual({
    required CreateReminderFromDocumentDate createFromDocumentDate,
    required CreateManualReminder createManual,
    required GetNotificationPermission getNotificationPermission,
    required RequestNotificationPermission requestNotificationPermission,
  }) : _createFromDocumentDate = createFromDocumentDate,
       _createManual = createManual,
       _getNotificationPermission = getNotificationPermission,
       _requestNotificationPermission = requestNotificationPermission,
       super(const ReminderFormEditing(title: '', isManual: true));

  final CreateReminderFromDocumentDate _createFromDocumentDate;
  final CreateManualReminder _createManual;
  final GetNotificationPermission _getNotificationPermission;
  final RequestNotificationPermission _requestNotificationPermission;

  void setTitle(String title) => _edit((s) => s.copyWith(title: title));

  void setDescription(String? description) =>
      _edit((s) => s.copyWith(description: description));

  /// Manual reminders only (F09-T04) — the from-document flow's event date
  /// is fixed at construction.
  void setEventDate(DateTime date) =>
      _edit((s) => _withDefaultAlertIfNeeded(s.copyWith(eventDate: date)));

  /// Manual reminders only (F09-T04).
  void setEventMinuteOfDay(int minuteOfDay) => _edit(
    (s) => _withDefaultAlertIfNeeded(s.copyWith(eventMinuteOfDay: minuteOfDay)),
  );

  /// Adds one alert (F09-T08). The picker sheet already excludes offsets
  /// already in use and the cap of three, so this trusts what it is given.
  void addAlert(ReminderAlertDraft draft) =>
      _edit((s) => s.copyWith(alerts: [...s.alerts, draft]));

  /// Removes the alert at [index] (F09-T08).
  void removeAlertAt(int index) =>
      _edit((s) => s.copyWith(alerts: [...s.alerts]..removeAt(index)));

  /// Starts the save. Notifications granted already: writes straight
  /// through. Not yet: stops at [ReminderFormNeedsNotificationPermission]
  /// instead, for the screen to show the permission sheet (F09-T09) — the
  /// write itself happens once the user answers it, via
  /// [allowNotificationsAndSave] or [saveWithoutNotifications].
  Future<void> save() async {
    final current = state;
    if (current is! ReminderFormEditing || !current.canSave) return;

    final permission = await _getNotificationPermission();
    if (isClosed) return;

    if (permission.valueOrNull == PermissionOutcome.granted) {
      await _persist(current);
    } else {
      emit(ReminderFormNeedsNotificationPermission(current));
    }
  }

  /// The permission sheet's «السماح بالتنبيهات» — asks the OS, then writes
  /// the reminder regardless of the answer (F09-T09): declining only means
  /// no OS notification ever fires for it, not that saving fails.
  Future<void> allowNotificationsAndSave() async {
    final current = state;
    if (current is! ReminderFormNeedsNotificationPermission) return;
    await _requestNotificationPermission();
    if (isClosed) return;
    await _persist(current.editing);
  }

  /// The permission sheet's «حفظ بدون تنبيه» — writes the reminder without
  /// asking for notifications at all.
  Future<void> saveWithoutNotifications() async {
    final current = state;
    if (current is! ReminderFormNeedsNotificationPermission) return;
    await _persist(current.editing);
  }

  /// The permission sheet was dismissed without a choice — back to editing,
  /// nothing written.
  void cancelNotificationPermissionPrompt() {
    final current = state;
    if (current is ReminderFormNeedsNotificationPermission) {
      emit(current.editing);
    }
  }

  Future<void> _persist(ReminderFormEditing editing) async {
    emit(editing.copyWith(isSaving: true));

    final alertTimes = [for (final alert in editing.alerts) alert.time];
    final outcome = editing.isManual
        ? await _createManual(
            title: editing.title.trim(),
            description: _normalized(editing.description),
            eventDate: editing.eventDate!,
            eventMinuteOfDay: editing.eventMinuteOfDay,
            alertTimes: alertTimes,
          )
        : await _createFromDocumentDate(
            documentId: editing.documentId,
            title: editing.title.trim(),
            description: _normalized(editing.description),
            eventDate: editing.eventDate!,
            eventMinuteOfDay: editing.eventMinuteOfDay,
            alertTimes: alertTimes,
          );
    if (isClosed) return;

    emit(
      outcome.when(
        ok: ReminderFormSaved.new,
        err: (failure) =>
            ReminderFormSaveFailed(editing.copyWith(isSaving: false), failure),
      ),
    );
  }

  void _edit(ReminderFormEditing Function(ReminderFormEditing) transform) {
    final current = state;
    if (current is! ReminderFormEditing || current.isSaving) return;
    emit(transform(current));
  }

  /// Seeds the manual form's first alert the moment both a date and a time
  /// are known — the design's own default, "right at the event" (F09-T04) —
  /// without overwriting anything the user already added themselves.
  static ReminderFormEditing _withDefaultAlertIfNeeded(
    ReminderFormEditing state,
  ) {
    if (state.alerts.isNotEmpty) return state;
    final instant = state.eventInstant;
    if (instant == null) return state;
    return state.copyWith(
      alerts: [
        ReminderAlertDraft(
          time: AlertTimeOffset.atEventTime.applyTo(instant),
          offset: AlertTimeOffset.atEventTime,
        ),
      ],
    );
  }

  /// The from-document form's default alert — "a day before", the design's
  /// own pre-checked choice — only when the paper gave a time to offset from
  /// (F09-T05); otherwise the form starts with none and the user must add
  /// one by hand (F09-T06).
  static List<ReminderAlertDraft> _defaultAlertsFor(
    DateTime eventDate,
    int? eventMinuteOfDay,
  ) {
    if (eventMinuteOfDay == null) return const [];
    final instant = cairoInstantOf(eventDate, eventMinuteOfDay);
    return [
      ReminderAlertDraft(
        time: AlertTimeOffset.oneDayBefore.applyTo(instant),
        offset: AlertTimeOffset.oneDayBefore,
      ),
    ];
  }
}

String? _normalized(String? raw) {
  final trimmed = raw?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
