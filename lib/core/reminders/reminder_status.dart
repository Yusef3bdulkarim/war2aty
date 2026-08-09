/// A reminder's own lifecycle — deliberately not "missed".
///
/// Only the user can mark a reminder [completed] («تم التنفيذ»); the app never
/// does it for them. "Missed" — القادمة vs الفائتة on the reminders list — is
/// not a third stored state: it is [pending] plus a due time that has already
/// passed, computed at read time (see the reminders list cubit, F09-T11).
/// Storing it separately would need a background job to flip it at the right
/// instant; deriving it needs nothing and can never drift out of sync with
/// "what time is it now".
enum ReminderStatus {
  pending,
  completed;

  bool get isPending => this == ReminderStatus.pending;
  bool get isCompleted => this == ReminderStatus.completed;
}
