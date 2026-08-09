/// The one OS-notification capability a reminder scheduler needs, behind a
/// plugin-free port — the same shape `OcrEngine`/`CameraService` wrap their
/// own plugins in (CLAUDE.md §B9). `ReminderScheduler`'s real implementation
/// depends on this, never on `flutter_local_notifications` directly, so it
/// can be driven by a fake in tests instead of a platform channel.
abstract interface class LocalNotificationsPort {
  /// Sets up whatever the platform needs before [schedule] can be called —
  /// the plugin itself, the timezone database, the Android channel. Called
  /// once, from the launch sequence.
  Future<void> initialize();

  /// Schedules one notification at the real instant [at] (UTC). Scheduling
  /// the same [id] again replaces whatever was there before.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    String? body,
  });

  /// Cancels [id]. Cancelling one that is not scheduled is a no-op.
  Future<void> cancel(int id);

  /// The ids the OS currently has scheduled — what
  /// `ReminderScheduler.reconcile` compares against what *should* be
  /// scheduled to know what to cancel.
  Future<Set<int>> pendingIds();
}
