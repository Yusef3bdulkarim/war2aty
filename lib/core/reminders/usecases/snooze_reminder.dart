import 'dart:async';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder_scheduler.dart';
import '../reminders_repository.dart';

/// Postpones a reminder to a single new alert time — «تأجيل» (F09-T12).
///
/// Reconciles afterward so the OS cancels the old alert and schedules the new
/// one — the snooze sheet never talks to the scheduler directly.
final class SnoozeReminder {
  const SnoozeReminder(this._repository, this._scheduler);

  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;

  Future<Result<void, AppFailure>> call(
    String id,
    DateTime newAlertTime,
  ) async {
    final result = await _repository.snoozeReminder(id, newAlertTime);
    if (result.isOk) unawaited(_scheduler.reconcile());
    return result;
  }
}
