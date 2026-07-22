import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../upcoming_reminder.dart';
import '../upcoming_reminder_repository.dart';

/// Streams the next due reminder for Home's upcoming card.
final class WatchUpcomingReminder {
  const WatchUpcomingReminder(this._repository);

  final UpcomingReminderRepository _repository;

  Stream<Result<UpcomingReminder?, AppFailure>> call() =>
      _repository.watchNext();
}
