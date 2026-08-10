import 'dart:async';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder.dart';
import '../reminder_scheduler.dart';
import '../reminders_repository.dart';

/// Creates a reminder the user entered by hand — «إضافة تذكير» (F09-T04).
///
/// Unlike [CreateReminderFromDocumentDate], [eventMinuteOfDay] is never
/// `null` in practice: the manual form marks the time required, since there
/// is no paper to be silent about it — the user is the source.
final class CreateManualReminder {
  const CreateManualReminder(this._repository, this._scheduler);

  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;

  Future<Result<Reminder, AppFailure>> call({
    required String title,
    String? description,
    required DateTime eventDate,
    int? eventMinuteOfDay,
    required List<DateTime> alertTimes,
  }) async {
    final result = await _repository.createReminder(
      title: title,
      description: description,
      eventDate: eventDate,
      eventMinuteOfDay: eventMinuteOfDay,
      isManual: true,
      alertTimes: alertTimes,
    );
    // Fire-and-forget, like every other reminder write reconciles (see
    // `LocalNotificationsReminderScheduler`'s own doc comment) — the new
    // reminder is saved either way, whether or not the OS side of it takes.
    if (result.isOk) unawaited(_scheduler.reconcile());
    return result;
  }
}
