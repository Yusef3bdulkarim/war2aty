import 'dart:async';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder_scheduler.dart';
import '../reminders_repository.dart';

/// Marks a reminder done — «تم التنفيذ» (F09-T12).
///
/// Reconciles afterward so the OS drops whatever notification the reminder's
/// alerts still had scheduled — a completed reminder should never still buzz.
final class CompleteReminder {
  const CompleteReminder(this._repository, this._scheduler);

  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;

  Future<Result<void, AppFailure>> call(String id) async {
    final result = await _repository.completeReminder(id);
    if (result.isOk) unawaited(_scheduler.reconcile());
    return result;
  }
}
