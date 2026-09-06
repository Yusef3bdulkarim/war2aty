import '../error/app_failure.dart';
import '../result/result.dart';
import 'reminder.dart';
import 'reminder_alert_status.dart';

/// Keeps reminders on the device (F09).
///
/// Lives in `core/` for the same reason `DocumentsRepository` does: more than
/// one feature reaches it — the reminders screens read and write through it,
/// while `ReminderScheduler` (F09-T10) reads [allReminders] to keep the OS
/// side in step, and `DriftDocumentsRepository` reads [remindersForDocument]
/// before a document delete cascades onto its reminder. Nothing here ever
/// reaches the network — a reminder stays on the phone (CLAUDE.md §7).
abstract interface class RemindersRepository {
  /// Watches every reminder, oldest event first. The reminders list (F09-T11)
  /// buckets these into القادمة/الفائتة/المكتملة itself — [Reminder.status]
  /// and [Reminder.isOverdue] carry everything that needs.
  Stream<Result<List<Reminder>, AppFailure>> watchReminders();

  /// Watches one reminder. Emits `null` once it is gone (completed-and-
  /// deleted, or a stale id) — an answer, not a failure.
  Stream<Result<Reminder?, AppFailure>> watchReminder(String id);

  /// Creates a reminder with its alert set, in one write.
  ///
  /// [alertTimes] must be 1–3 real instants (UTC) — a reminder is never saved
  /// with zero alerts (F09-T08's cap is enforced by the form, not here, but
  /// "at least one" is a data invariant every write path shares).
  Future<Result<Reminder, AppFailure>> createReminder({
    String? documentId,
    required String title,
    String? description,
    required DateTime eventDate,
    int? eventMinuteOfDay,
    required bool isManual,
    required List<DateTime> alertTimes,
  });

  /// Updates the fields a reminder's own edit form can change. Any argument
  /// left `null` (or absent, for [alertTimes]) keeps its current value;
  /// [clearDescription] is the explicit way to blank the note, the same
  /// "separate flag" shape `DocumentsRepository.setNote` uses.
  ///
  /// Passing [alertTimes] replaces the whole alert set (F09-T08) — there is
  /// no per-alert update, only "these are the alerts now".
  Future<Result<void, AppFailure>> updateReminder(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
    List<DateTime>? alertTimes,
  });

  /// Marks a reminder done — «تم التنفيذ» (F09-T12).
  Future<Result<void, AppFailure>> completeReminder(String id);

  /// Postpones a reminder to a single new alert time, replacing whatever
  /// alerts it had (F09-T12). Snoozing changes *when the notification fires*
  /// only — the event date/time it was created from is untouched.
  Future<Result<void, AppFailure>> snoozeReminder(
    String id,
    DateTime newAlertTime,
  );

  /// Deletes one reminder. Its alerts go with it through the cascade.
  Future<Result<void, AppFailure>> deleteReminder(String id);

  /// Deletes every reminder — settings' «حذف كل التذكيرات».
  Future<Result<void, AppFailure>> deleteAllReminders();

  /// Every reminder still pending, for [ReminderScheduler.reconcile]
  /// (F09-T13) to check against what the OS actually has scheduled.
  Future<Result<List<Reminder>, AppFailure>> pendingReminders();

  /// Every reminder linked to [documentId] — read before the document is
  /// deleted, while the alert ids/notification ids are still there to cancel.
  Future<Result<List<Reminder>, AppFailure>> remindersForDocument(
    String documentId,
  );

  /// Records what the scheduler learned about one alert — scheduled, failed,
  /// or (best-effort, on reconcile) delivered. Bookkeeping only: nothing in
  /// the app reads an alert's status to decide whether to show a reminder,
  /// only to decide whether it still counts as "next" (F09-T10/T13).
  Future<Result<void, AppFailure>> setAlertStatus(
    String alertId,
    ReminderAlertStatus status,
  );
}
