import '../error/app_failure.dart';
import '../localization/app_strings.dart';
import '../localization/ar_strings.dart';
import '../localization/en_strings.dart';
import '../localization/usecases/get_saved_locale.dart';
import '../result/result.dart';
import 'local_notifications_port.dart';
import 'notification_id.dart';
import 'reminder.dart';
import 'reminder_alert.dart';
import 'reminder_alert_status.dart';
import 'reminder_notification_content.dart';
import 'reminder_scheduler.dart';
import 'reminders_repository.dart';
import 'usecases/get_hide_sensitive_notification_details.dart';

/// [ReminderScheduler] driven by a [LocalNotificationsPort] (F09-T10).
///
/// Reconciliation, not per-operation scheduling: every write to the
/// reminders table (create, edit, snooze, complete, delete) and every app
/// launch (F09-T13) calls the same [reconcile] — it reads what *should* be
/// scheduled from [RemindersRepository] and makes the OS agree, rather than
/// the app tracking "what did I already tell the OS" itself. That is also
/// how a document's cascade-deleted reminder (`DriftDocumentsRepository`)
/// loses its notification without either repository importing the other.
final class LocalNotificationsReminderScheduler implements ReminderScheduler {
  const LocalNotificationsReminderScheduler(
    this._notifications,
    this._repository,
    this._getSavedLocale,
    this._getHideSensitiveDetails,
  );

  final LocalNotificationsPort _notifications;
  final RemindersRepository _repository;
  final GetSavedLocale _getSavedLocale;

  /// Reads the notification-privacy setting's current value (F09-T14),
  /// defaulting on (hidden) until the user explicitly reveals it.
  final GetHideSensitiveNotificationDetails _getHideSensitiveDetails;

  @override
  Future<Result<int, AppFailure>> reconcile() async {
    final pendingResult = await _repository.pendingReminders();
    if (pendingResult case Err(:final failure)) return Err(failure);
    final reminders = (pendingResult as Ok<List<Reminder>, AppFailure>).value;

    final now = DateTime.now().toUtc();
    final due = <(Reminder, ReminderAlert)>[
      for (final reminder in reminders)
        for (final alert in reminder.alerts)
          if (alert.status != ReminderAlertStatus.cancelled &&
              alert.scheduledAt.isAfter(now))
            (reminder, alert),
    ];
    final dueIds = {for (final (_, alert) in due) notificationIdOf(alert.id)};

    // Cancel whatever the OS still has that should not exist any more — a
    // deleted/completed/edited reminder, or an alert that was removed
    // (F09-T08) or replaced by a snooze (F09-T12).
    final pendingIds = await _notifications.pendingIds();
    for (final id in pendingIds) {
      if (!dueIds.contains(id)) {
        await _notifications.cancel(id);
      }
    }

    // Best-effort bookkeeping: a still-`scheduled` alert whose time has
    // already passed almost certainly fired. Nothing reads this to decide
    // whether to show a reminder — only `Reminder.nextAlert`/`isOverdue`
    // read alert status, and both already treat a past alert as no longer
    // "next" regardless — but it keeps the stored status honest.
    for (final reminder in reminders) {
      for (final alert in reminder.alerts) {
        if (alert.status == ReminderAlertStatus.scheduled &&
            !alert.scheduledAt.isAfter(now)) {
          await _repository.setAlertStatus(
            alert.id,
            ReminderAlertStatus.delivered,
          );
        }
      }
    }

    if (due.isEmpty) return const Ok(0);

    final strings = await _currentStrings();
    // Read once per reconcile, not once per alert — the setting cannot
    // change mid-batch, and there is no reason to hit the database again
    // for every alert in it.
    final hideSensitiveDetails = await _getHideSensitiveDetails();
    var scheduledCount = 0;
    for (final (reminder, alert) in due) {
      final content = reminderNotificationContent(
        reminder,
        strings,
        hideSensitiveDetails: hideSensitiveDetails,
      );
      try {
        await _notifications.schedule(
          id: notificationIdOf(alert.id),
          at: alert.scheduledAt,
          title: content.title,
          body: content.body,
        );
        await _repository.setAlertStatus(
          alert.id,
          ReminderAlertStatus.scheduled,
        );
        scheduledCount++;
      }
      // The OS scheduling call can fail for reasons outside this app's
      // control (denied permission, a platform channel error); the
      // reminder itself is still saved either way (§B5) — only its OS-side
      // alarm did not take.
      on Object {
        await _repository.setAlertStatus(alert.id, ReminderAlertStatus.failed);
      }
    }

    return Ok(scheduledCount);
  }

  Future<AppStrings> _currentStrings() async {
    final code = await _getSavedLocale();
    return code == 'en' ? const EnStrings() : const ArStrings();
  }
}
