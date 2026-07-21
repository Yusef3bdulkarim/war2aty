/// The ordered phases of app launch, in the order they run.
///
/// The splash screen surfaces the active stage so a slow launch shows progress
/// instead of a frozen screen.
enum BootstrapStage {
  /// Establishing the anonymous identity/session.
  session,

  /// Loading runtime configuration (limits, flags, timeouts).
  config,

  /// Deleting stale temporary analysis files.
  cleanup,

  /// Re-aligning scheduled reminders with the database.
  reminders,

  /// Syncing the daily usage counter.
  usage,
}
