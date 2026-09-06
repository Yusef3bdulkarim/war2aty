import 'dart:async';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder_scheduler.dart';
import '../reminders_repository.dart';

/// Permanently deletes one reminder — «حذف» on its details screen (F09-T12).
///
/// Reconciles afterward so the OS drops whatever notifications the deleted
/// reminder's alerts still had scheduled.
final class DeleteReminder {
  const DeleteReminder(this._repository, this._scheduler);

  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;

  Future<Result<void, AppFailure>> call(String id) async {
    final result = await _repository.deleteReminder(id);
    if (result.isOk) unawaited(_scheduler.reconcile());
    return result;
  }
}
