import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/reminders/reminder.dart';
import '../../../../core/reminders/usecases/complete_reminder.dart';
import '../../../../core/reminders/usecases/delete_reminder.dart';
import '../../../../core/reminders/usecases/snooze_reminder.dart';
import '../../../../core/reminders/usecases/watch_reminder.dart';
import '../../../../core/result/result.dart';
import 'reminder_details_state.dart';

/// Feeds «تفاصيل التذكير» (F09-T12): the reminder itself, and the actions the
/// screen offers — complete, snooze, delete.
///
/// Depends on use cases only (architecture rule); it never sees
/// `RemindersRepository` directly.
final class ReminderDetailsCubit extends Cubit<ReminderDetailsState> {
  ReminderDetailsCubit(
    this._watchReminder,
    this._completeReminder,
    this._snoozeReminder,
    this._deleteReminder,
  ) : super(const ReminderDetailsLoading());

  final WatchReminder _watchReminder;
  final CompleteReminder _completeReminder;
  final SnoozeReminder _snoozeReminder;
  final DeleteReminder _deleteReminder;

  StreamSubscription<void>? _reminderSubscription;

  /// Starts watching [id]. Safe to call more than once.
  void start(String id) {
    if (_reminderSubscription != null) return;
    _reminderSubscription = _watchReminder(id).listen((result) {
      if (isClosed) return;
      switch (result) {
        case Ok(value: final reminder):
          if (reminder == null) {
            emit(const ReminderDetailsNotFound());
            return;
          }
          emit(ReminderDetailsAvailable(reminder));
        case Err(:final failure):
          emit(ReminderDetailsUnavailable(failure));
      }
    });
  }

  /// «تم التنفيذ» — a direct action, no confirmation (matches the design).
  /// The screen updates on its own once the watched stream re-emits; this
  /// only reports whether the write itself succeeded, for a failure snackbar.
  Future<bool> complete() async {
    final reminder = _currentReminder;
    if (reminder == null) return false;
    final result = await _completeReminder(reminder.id);
    return result.isOk;
  }

  /// «تأجيل» — replaces every alert with one at [newAlertTime].
  Future<bool> snooze(DateTime newAlertTime) async {
    final reminder = _currentReminder;
    if (reminder == null) return false;
    final result = await _snoozeReminder(reminder.id, newAlertTime);
    return result.isOk;
  }

  /// «حذف» — permanent, after the caller has already confirmed.
  Future<bool> delete() async {
    final reminder = _currentReminder;
    if (reminder == null) return false;
    final result = await _deleteReminder(reminder.id);
    return result.isOk;
  }

  Reminder? get _currentReminder {
    final current = state;
    return current is ReminderDetailsAvailable ? current.reminder : null;
  }

  @override
  Future<void> close() async {
    await _reminderSubscription?.cancel();
    return super.close();
  }
}
