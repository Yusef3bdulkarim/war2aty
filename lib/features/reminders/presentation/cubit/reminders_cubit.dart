import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/reminders/usecases/watch_reminders.dart';
import 'reminders_state.dart';

/// Feeds the «التذكيرات» screen from the local database (F09-T11).
///
/// Depends on its use case only (architecture rule); it never sees the
/// repository or the database.
final class RemindersCubit extends Cubit<RemindersState> {
  RemindersCubit(this._watchReminders) : super(const RemindersLoading());

  final WatchReminders _watchReminders;

  StreamSubscription<void>? _subscription;

  /// Starts watching the list. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    _subscription = _watchReminders().listen((result) {
      if (isClosed) return;
      // Keeps the tab the user is on across a live update — a new reminder
      // arriving should not silently switch them back to «القادمة».
      final current = state;
      final tab = current is RemindersAvailable
          ? current.tab
          : RemindersTab.upcoming;
      emit(
        result.when(
          ok: (reminders) => RemindersAvailable(reminders, tab: tab),
          err: RemindersUnavailable.new,
        ),
      );
    });
  }

  /// Switches which bucket is on screen (F09-T11). A no-op once the list
  /// has not arrived yet, or [tab] is already selected.
  void setTab(RemindersTab tab) {
    final current = state;
    if (current is! RemindersAvailable || current.tab == tab) return;
    emit(RemindersAvailable(current.reminders, tab: tab));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
