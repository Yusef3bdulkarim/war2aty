import '../../../../core/error/app_failure.dart';
import '../../../../core/reminders/reminder.dart';

/// «تفاصيل التذكير» (F09-T12).
sealed class ReminderDetailsState {
  const ReminderDetailsState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No answer from the database yet.
final class ReminderDetailsLoading extends ReminderDetailsState {
  const ReminderDetailsLoading();
}

/// [reminder] itself.
final class ReminderDetailsAvailable extends ReminderDetailsState {
  const ReminderDetailsAvailable(this.reminder);

  final Reminder reminder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderDetailsAvailable && other.reminder == reminder;

  @override
  int get hashCode => reminder.hashCode;
}

/// The reminder is gone — deleted (by this screen or elsewhere), or a stale
/// id. An answer, not a failure: the screen has nothing left to show and
/// backs out, the same way `DocumentDetailsScreen`'s own "not found" state
/// does.
final class ReminderDetailsNotFound extends ReminderDetailsState {
  const ReminderDetailsNotFound();
}

/// The reminder could not be read.
final class ReminderDetailsUnavailable extends ReminderDetailsState {
  const ReminderDetailsUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderDetailsUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(ReminderDetailsUnavailable, failure);
}
