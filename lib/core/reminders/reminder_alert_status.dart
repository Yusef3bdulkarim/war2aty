/// One alert's own standing with the OS notification scheduler.
///
/// The Drift row is the source of truth (F09 §41); this says how well the OS
/// side currently agrees with it, so reconcile-on-restart (F09-T13) knows
/// what to leave alone, what to (re)schedule, and what merely to note.
enum ReminderAlertStatus {
  /// Handed to the OS scheduler and, as far as the app knows, still pending.
  scheduled,

  /// The OS reported the notification fired. Informational only — nothing
  /// reads this to decide what to show; the reminder itself still needs the
  /// user to complete it.
  delivered,

  /// Cancelled deliberately — the reminder was snoozed, edited, completed, or
  /// deleted before this alert fired.
  cancelled,

  /// Scheduling this alert with the OS failed (e.g. exact-alarm permission
  /// missing). The reminder still exists; only its OS-side alarm does not.
  failed;

  bool get isActive => this == ReminderAlertStatus.scheduled;
}
