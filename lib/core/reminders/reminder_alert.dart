import 'reminder_alert_status.dart';

/// One moment a reminder should notify at.
///
/// A reminder can carry up to three of these (F09-T08), each scheduled and
/// cancelled independently — see `Reminder.nextAlert` for how the list and
/// Home decide which one to show.
final class ReminderAlert {
  const ReminderAlert({
    required this.id,
    required this.reminderId,
    required this.scheduledAt,
    required this.status,
  });

  final String id;
  final String reminderId;

  /// The real instant (UTC) the OS should fire at — already resolved from
  /// whatever Cairo wall-clock time the user chose.
  final DateTime scheduledAt;

  final ReminderAlertStatus status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAlert &&
          other.id == id &&
          other.reminderId == reminderId &&
          other.scheduledAt == scheduledAt &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, reminderId, scheduledAt, status);

  @override
  String toString() => 'ReminderAlert($id, $status)';
}
