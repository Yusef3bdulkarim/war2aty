import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder_notification_response.dart';
import '../reminder_scheduler.dart';
import '../reminders_repository.dart';

/// How far «أجّل ساعة» pushes a reminder (F25 locked decision #6).
const Duration kNotificationSnoozeDuration = Duration(hours: 1);

/// Does what a notification's button asked — «تم» completes the reminder,
/// «أجّل ساعة» snoozes it an hour from now (F25-T03).
///
/// Unlike `CompleteReminder`/`SnoozeReminder`, which fire their reconcile
/// and forget it, this awaits it: a button pressed from the notification
/// may run in a background engine the OS can tear down as soon as this
/// returns (F25-T05), and the snoozed alert must already be with the OS by
/// then. A failed reconcile does not fail the action — the database write
/// stands, and the next launch reconciles again (F09-T13).
///
/// The notification can outlive what it was for: a reminder completed or
/// deleted in the app since it fired still has its notification in the
/// tray. Pressing a button on one of those does nothing — snoozing a
/// completed reminder must not bring it back.
final class HandleReminderNotificationAction {
  HandleReminderNotificationAction(
    this._repository,
    this._scheduler, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;
  final DateTime Function() _now;

  Future<Result<void, AppFailure>> call(
    String reminderId,
    ReminderNotificationAction action,
  ) async {
    final pending = await _repository.pendingReminders();
    final List<String> pendingIds;
    switch (pending) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        pendingIds = [for (final reminder in value) reminder.id];
    }
    if (!pendingIds.contains(reminderId)) return const Ok(null);

    final result = switch (action) {
      ReminderNotificationAction.complete => await _repository.completeReminder(
        reminderId,
      ),
      ReminderNotificationAction.snooze => await _repository.snoozeReminder(
        reminderId,
        _now().toUtc().add(kNotificationSnoozeDuration),
      ),
    };
    if (result.isErr) return result;

    await _scheduler.reconcile();
    return result;
  }
}
