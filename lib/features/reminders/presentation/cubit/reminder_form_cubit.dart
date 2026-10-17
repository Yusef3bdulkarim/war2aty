import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/permissions/usecases/get_notification_permission.dart';
import '../../../../core/permissions/usecases/request_notification_permission.dart';
import '../../../../core/reminders/alert_time_offset.dart';
import '../../../../core/reminders/usecases/create_manual_reminder.dart';
import '../../../../core/reminders/usecases/create_reminder_from_document_date.dart';
import '../../../../core/time/cairo_day.dart';
import '../models/manual_reminder_seed.dart';
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

  /// A reminder entered by hand — every field starts empty and the user fills
  /// in the title, date, time and alerts themselves.
  ///
  /// With a [seed] (F29), the event date and time start filled in instead:
  /// the empty reminders list offers three ready dates, and tapping one opens
  /// this same form rather than a different screen. The title is still the
  /// user's to write, and every field, the date included, stays editable from
  /// here — a seed is a starting point, not a decision.
  ReminderFormCubit.manual({
    required CreateReminderFromDocumentDate createFromDocumentDate,
    required CreateManualReminder createManual,
    required GetNotificationPermission getNotificationPermission,
    required RequestNotificationPermission requestNotificationPermission,
    ManualReminderSeed? seed,
  }) : _createFromDocumentDate = createFromDocumentDate,
       _createManual = createManual,
       _getNotificationPermission = getNotificationPermission,
       _requestNotificationPermission = requestNotificationPermission,
       super(_manualInitialState(seed));

  final CreateReminderFromDocumentDate _createFromDocumentDate;
  final CreateManualReminder _createManual;
  final GetNotificationPermission _getNotificationPermission;
  final RequestNotificationPermission _requestNotificationPermission;

  void setTitle(String title) => _edit((s) => s.copyWith(title: title));

  void setDescription(String? description) =>
      _edit((s) => s.copyWith(description: description));

  /// Manual reminders only (F09-T04) — the from-document flow's event date
  /// is fixed at construction.
  void setEventDate(DateTime date) => _edit(
    (s) => _withDefaultAlertIfNeeded(_reanchored(s.copyWith(eventDate: date))),
  );

  /// Manual reminders only (F09-T04).
  void setEventMinuteOfDay(int minuteOfDay) => _edit(
    (s) => _withDefaultAlertIfNeeded(
      _reanchored(s.copyWith(eventMinuteOfDay: minuteOfDay)),
    ),
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

  /// The manual form's opening state, with or without a [seed] (F29).
  ///
  /// A seeded form is built to be **indistinguishable** from one the user
  /// filled in by hand: it goes through the very same
  /// [_withDefaultAlertIfNeeded] that `setEventDate`/`setEventMinuteOfDay`
  /// run, so it opens with the same "at the event's time" alert already
  /// there. Without that, a seeded form would arrive with no alerts and
  /// `canSave` false — the user would have to add one by hand, which is more
  /// work than typing the date was.
  static ReminderFormEditing _manualInitialState(ManualReminderSeed? seed) {
    if (seed == null) {
      return const ReminderFormEditing(title: '', isManual: true);
    }
    return _withDefaultAlertIfNeeded(
      ReminderFormEditing(
        title: '',
        isManual: true,
        eventDate: seed.eventDate,
        eventMinuteOfDay: seed.eventMinuteOfDay,
      ),
    );
  }

  /// Moves every preset-derived alert to follow the event it is relative to.
  ///
  /// A [ReminderAlertDraft] stores an absolute instant, and its row is
  /// labelled from its `offset` alone («في وقت الحدث», «قبل الموعد بيوم») —
  /// so without this, changing the event date left each preset alert sitting
  /// on the old one while still *claiming* to be relative to the new one.
  /// The form showed the right words over the wrong time, and the reminder
  /// fired on the wrong day. Found while building F29's seeded form, which
  /// makes it the common case: a seeded form opens with an alert already
  /// there, so the user's very first edit of the date would hit it.
  ///
  /// A hand-picked alert (`offset == null`) is left exactly where it is. The
  /// user named that instant; it was never a function of the event.
  ///
  /// Does nothing until the event has both a date and a time — there is no
  /// instant to be relative to before that.
  static ReminderFormEditing _reanchored(ReminderFormEditing state) {
    final instant = state.eventInstant;
    if (instant == null || state.alerts.isEmpty) return state;

    return state.copyWith(
      alerts: [
        for (final alert in state.alerts)
          if (alert.offset case final offset?)
            ReminderAlertDraft(time: offset.applyTo(instant), offset: offset)
          else
            alert,
      ],
    );
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
