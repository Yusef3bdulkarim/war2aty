import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/usecases/watch_recent_documents.dart';
import '../../../../core/reminders/usecases/watch_upcoming_reminder.dart';
import '../../../../core/usage/usecases/watch_daily_usage.dart';
import 'home_state.dart';

/// Feeds the Home screen from the local database.
///
/// Subscribes to use cases only, and holds every subscription so they can be
/// cancelled in [close] — a Drift stream lives as long as the database, so an
/// abandoned listener would keep pushing into a disposed cubit.
final class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required WatchDailyUsage watchDailyUsage,
    required WatchRecentDocuments watchRecentDocuments,
    required WatchUpcomingReminder watchUpcomingReminder,
  }) : _watchDailyUsage = watchDailyUsage,
       _watchRecentDocuments = watchRecentDocuments,
       _watchUpcomingReminder = watchUpcomingReminder,
       super(const HomeState());

  final WatchDailyUsage _watchDailyUsage;
  final WatchRecentDocuments _watchRecentDocuments;
  final WatchUpcomingReminder _watchUpcomingReminder;

  final List<StreamSubscription<void>> _subscriptions = [];

  /// Starts watching every section. Safe to call more than once.
  void start() {
    if (_subscriptions.isNotEmpty) return;

    _subscriptions.add(
      _watchDailyUsage().listen((result) {
        if (isClosed) return;
        emit(
          state.copyWith(
            usage: result.when(
              ok: UsageAvailable.new,
              err: UsageUnavailable.new,
            ),
          ),
        );
      }),
    );

    _subscriptions.add(
      _watchUpcomingReminder().listen((result) {
        if (isClosed) return;
        emit(
          state.copyWith(
            reminder: result.when(
              ok: ReminderAvailable.new,
              err: ReminderUnavailable.new,
            ),
          ),
        );
      }),
    );

    _subscriptions.add(
      _watchRecentDocuments().listen((result) {
        if (isClosed) return;
        emit(
          state.copyWith(
            documents: result.when(
              ok: DocumentsAvailable.new,
              err: DocumentsUnavailable.new,
            ),
          ),
        );
      }),
    );
  }

  @override
  Future<void> close() async {
    // Every section holds a stream that outlives the screen, so all of them
    // have to be released — missing one leaks a listener onto a dead cubit.
    await Future.wait(_subscriptions.map((s) => s.cancel()));
    return super.close();
  }
}
