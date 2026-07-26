import '../error/app_failure.dart';
import '../result/result.dart';
import 'upcoming_reminder.dart';

/// Reads the single next reminder due.
///
/// Narrow and read-only, like the recent-documents port: Home needs one row,
/// not the reminders feature's full repository (F09).
abstract interface class UpcomingReminderRepository {
  /// Emits the next due reminder, then every later change.
  ///
  /// `Ok(null)` means "nothing scheduled" — a normal answer. Failures arrive
  /// as `Err` values rather than stream errors.
  Stream<Result<UpcomingReminder?, AppFailure>> watchNext();
}
