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

/// [reminder], plus its linked document's title if it has one.
///
/// [linkedDocumentTitle] is `null` while [Reminder.documentId] is `null`
/// (nothing to show), while the linked document's own read is still in
/// flight, or once that document has been deleted out from under the
/// reminder — the row that shows it treats all three the same way, since
/// none of them is something the user can act on from here.
final class ReminderDetailsAvailable extends ReminderDetailsState {
  const ReminderDetailsAvailable(this.reminder, {this.linkedDocumentTitle});

  final Reminder reminder;
  final String? linkedDocumentTitle;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderDetailsAvailable &&
          other.reminder == reminder &&
          other.linkedDocumentTitle == linkedDocumentTitle;

  @override
  int get hashCode => Object.hash(reminder, linkedDocumentTitle);
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
