import '../../../../core/error/app_failure.dart';
import '../../../../core/reminders/reminder.dart';
import '../../../../core/utils/list_equality.dart';

/// القادمة / الفائتة / المكتملة — the reminders list's own three buckets
/// (F09-T11). Not stored on [Reminder] itself (see `ReminderStatus`'s own
/// doc comment): "missed" is derived from [Reminder.isOverdue], not a fourth
/// database value.
enum RemindersTab { upcoming, missed, completed }

sealed class RemindersState {
  const RemindersState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No list has arrived from the database yet.
final class RemindersLoading extends RemindersState {
  const RemindersLoading();
}

/// Every reminder, bucketed by [tab] — an empty bucket is an answer, not a
/// failure, the same convention the documents list uses for its own empty
/// library.
final class RemindersAvailable extends RemindersState {
  RemindersAvailable(this.reminders, {this.tab = RemindersTab.upcoming})
    : upcoming = _upcoming(reminders),
      missed = _missed(reminders),
      completed = _completed(reminders);

  final List<Reminder> reminders;
  final RemindersTab tab;

  final List<Reminder> upcoming;
  final List<Reminder> missed;
  final List<Reminder> completed;

  /// The bucket [tab] currently selects.
  List<Reminder> get visible => switch (tab) {
    RemindersTab.upcoming => upcoming,
    RemindersTab.missed => missed,
    RemindersTab.completed => completed,
  };

  /// Nothing has ever been saved — the empty state that offers to create
  /// one, rather than the tab-specific "nothing here" states.
  bool get hasNoReminders => reminders.isEmpty;

  /// Pending, with a future alert still to fire — soonest first.
  static List<Reminder> _upcoming(List<Reminder> reminders) {
    final list = reminders
        .where((r) => r.status.isPending && !r.isOverdue())
        .toList();
    list.sort(_byNextAlert);
    return list;
  }

  /// Pending, with every alert already in the past — most recently missed
  /// first.
  static List<Reminder> _missed(List<Reminder> reminders) {
    final list = reminders.where((r) => r.isOverdue()).toList();
    list.sort((a, b) => _dueInstant(b).compareTo(_dueInstant(a)));
    return list;
  }

  /// Marked done — most recently completed first.
  static List<Reminder> _completed(List<Reminder> reminders) {
    final list = reminders.where((r) => r.status.isCompleted).toList();
    list.sort((a, b) {
      final aAt = a.completedAt, bAt = b.completedAt;
      if (aAt == null || bAt == null) return 0;
      return bAt.compareTo(aAt);
    });
    return list;
  }

  static int _byNextAlert(Reminder a, Reminder b) =>
      _dueInstant(a).compareTo(_dueInstant(b));

  /// The instant a reminder is "due at" for sorting purposes: its next
  /// active alert, or its event's own instant/day when every alert is
  /// already resolved one way or another.
  static DateTime _dueInstant(Reminder r) =>
      r.nextAlert?.scheduledAt ?? r.eventInstant ?? r.eventDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemindersAvailable &&
          other.tab == tab &&
          listEquals(other.reminders, reminders);

  @override
  int get hashCode => Object.hash(tab, Object.hashAll(reminders));
}

/// The list could not be read.
final class RemindersUnavailable extends RemindersState {
  const RemindersUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemindersUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(RemindersUnavailable, failure);
}
