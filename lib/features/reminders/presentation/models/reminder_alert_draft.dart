import '../../../../core/reminders/alert_time_offset.dart';

/// One alert time chosen while building or editing a reminder, before it is
/// saved.
///
/// UI model — presentation only. [ReminderFormCubit] (F09-T03/T04) holds a
/// list of up to three of these (F09-T08) and turns them into plain
/// `DateTime` instants when it calls `RemindersRepository`.
final class ReminderAlertDraft {
  const ReminderAlertDraft({required this.time, this.offset});

  /// The real instant (UTC) this alert fires at.
  final DateTime time;

  /// The preset it was chosen from, if any — drives its label via
  /// `alertTimeLabel`. `null` for a hand-picked absolute time.
  final AlertTimeOffset? offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderAlertDraft &&
          other.time == time &&
          other.offset == offset;

  @override
  int get hashCode => Object.hash(time, offset);
}
