/// The next reminder the user has coming up.
///
/// Carries only what a summary row shows. The full reminder — its document
/// link, snooze history and notification state — belongs to F09.
final class UpcomingReminder {
  const UpcomingReminder({
    required this.id,
    required this.title,
    required this.dueAt,
  });

  final String id;
  final String title;

  /// When it fires, in UTC. Rendering converts to the user's day.
  final DateTime dueAt;

  @override
  bool operator ==(Object other) =>
      other is UpcomingReminder &&
      other.id == id &&
      other.title == title &&
      other.dueAt == dueAt;

  @override
  int get hashCode => Object.hash(id, title, dueAt);
}
