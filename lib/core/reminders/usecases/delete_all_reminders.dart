import 'dart:async';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder_scheduler.dart';
import '../reminders_repository.dart';

/// Permanently deletes every reminder — «حذف كل التذكيرات» in settings
/// (F11-T11).
///
/// Reconciles afterward so the OS drops whatever notifications every deleted
/// reminder's alerts still had scheduled — [RemindersRepository] itself has
/// no [ReminderScheduler] to call this with, the same reasoning
/// [DeleteReminder] applies to a single reminder.
final class DeleteAllReminders {
  const DeleteAllReminders(this._repository, this._scheduler);

  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;

  Future<Result<void, AppFailure>> call() async {
    final result = await _repository.deleteAllReminders();
    if (result.isOk) unawaited(_scheduler.reconcile());
    return result;
  }
}
