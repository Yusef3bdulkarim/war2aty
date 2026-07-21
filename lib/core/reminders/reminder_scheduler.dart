import '../error/app_failure.dart';
import '../result/result.dart';

/// Keeps OS-level scheduled notifications in step with the reminders stored in
/// the local database.
///
/// The contract lives in `core/` because two features meet here: bootstrap
/// *calls* it at launch, while reminders (F09) *implements* it — neither should
/// import the other directly.
///
/// Reconciliation is needed because the OS can silently lose scheduled
/// notifications: after a reboot, an app update, a force-stop, or a timezone
/// change. Reminders may also have been added or deleted while the app was
/// closed. Re-aligning on every launch keeps the two views consistent.
abstract interface class ReminderScheduler {
  /// Re-schedules what should be pending and cancels what should not.
  /// Returns how many reminders were reconciled.
  Future<Result<int, AppFailure>> reconcile();
}

/// Placeholder used until F09 builds real scheduling.
///
/// Deliberately does nothing and always succeeds, so the launch sequence can
/// already call the hook without special-casing its absence.
final class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<Result<int, AppFailure>> reconcile() async => const Ok(0);
}
