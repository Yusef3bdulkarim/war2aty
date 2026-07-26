import '../error/app_failure.dart';
import '../result/result.dart';
import 'upcoming_reminder.dart';
import 'upcoming_reminder_repository.dart';

/// Stands in until F09 builds the `reminders` table.
///
/// Reports "nothing scheduled" rather than failing, so Home shows its real
/// empty state. Swapped for the Drift-backed implementation in F09.
final class StubUpcomingReminderRepository
    implements UpcomingReminderRepository {
  const StubUpcomingReminderRepository();

  @override
  Stream<Result<UpcomingReminder?, AppFailure>> watchNext() =>
      Stream.value(const Ok(null));
}
