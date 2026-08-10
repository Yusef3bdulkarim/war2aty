import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder.dart';
import '../reminders_repository.dart';

/// Streams every reminder for the «التذكيرات» screen (F09-T11).
///
/// Unlike `WatchUpcomingReminder` (Home's single-row port), this is the
/// reminders feature's own full list — bucketing into
/// القادمة/الفائتة/المكتملة is the screen's job, from [Reminder.status] and
/// [Reminder.isOverdue].
final class WatchReminders {
  const WatchReminders(this._repository);

  final RemindersRepository _repository;

  Stream<Result<List<Reminder>, AppFailure>> call() =>
      _repository.watchReminders();
}
