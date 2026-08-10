import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder.dart';
import '../reminders_repository.dart';

/// Streams one reminder, for the details screen (F09-T12).
final class WatchReminder {
  const WatchReminder(this._repository);

  final RemindersRepository _repository;

  Stream<Result<Reminder?, AppFailure>> call(String id) =>
      _repository.watchReminder(id);
}
