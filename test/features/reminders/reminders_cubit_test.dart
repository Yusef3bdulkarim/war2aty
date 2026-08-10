import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminders.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminders_state.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRemindersRepository repository;
  late RemindersCubit cubit;

  setUp(() {
    repository = FakeRemindersRepository();
    cubit = RemindersCubit(WatchReminders(repository));
  });
  tearDown(() => cubit.close());

  test('starts loading', () {
    expect(cubit.state, isA<RemindersLoading>());
  });

  test('start subscribes and reflects an empty library', () async {
    cubit.start();
    repository.emit([]);
    await pumpEventQueue();

    final state = cubit.state as RemindersAvailable;
    expect(state.hasNoReminders, isTrue);
  });

  test('start is safe to call twice', () async {
    cubit.start();
    cubit.start();
    repository.emit([fakeReminder()]);
    await pumpEventQueue();

    expect((cubit.state as RemindersAvailable).reminders, hasLength(1));
  });

  test('a read failure surfaces as RemindersUnavailable', () async {
    cubit.start();
    repository.emitFailure();
    await pumpEventQueue();

    expect(cubit.state, isA<RemindersUnavailable>());
  });

  group('bucketing', () {
    final now = DateTime.now().toUtc();

    test('a pending reminder with a future alert is upcoming', () async {
      cubit.start();
      repository.emit([
        fakeReminder(alertTimes: [now.add(const Duration(days: 1))]),
      ]);
      await pumpEventQueue();

      final state = cubit.state as RemindersAvailable;
      expect(state.upcoming, hasLength(1));
      expect(state.missed, isEmpty);
    });

    test('a pending reminder with every alert past is missed', () async {
      cubit.start();
      repository.emit([
        fakeReminder(alertTimes: [now.subtract(const Duration(days: 1))]),
      ]);
      await pumpEventQueue();

      final state = cubit.state as RemindersAvailable;
      expect(state.missed, hasLength(1));
      expect(state.upcoming, isEmpty);
    });

    test('a completed reminder is neither upcoming nor missed', () async {
      cubit.start();
      repository.emit([
        fakeReminder(
          status: ReminderStatus.completed,
          alertTimes: [now.subtract(const Duration(days: 1))],
        ),
      ]);
      await pumpEventQueue();

      final state = cubit.state as RemindersAvailable;
      expect(state.completed, hasLength(1));
      expect(state.missed, isEmpty);
      expect(state.upcoming, isEmpty);
    });

    test('upcoming sorts soonest first', () async {
      cubit.start();
      repository.emit([
        fakeReminder(
          id: 'later',
          alertTimes: [now.add(const Duration(days: 5))],
        ),
        fakeReminder(
          id: 'sooner',
          alertTimes: [now.add(const Duration(days: 1))],
        ),
      ]);
      await pumpEventQueue();

      final state = cubit.state as RemindersAvailable;
      expect(state.upcoming.map((r) => r.id), ['sooner', 'later']);
    });
  });

  group('setTab', () {
    test('switches the visible bucket', () async {
      cubit.start();
      repository.emit([fakeReminder(status: ReminderStatus.completed)]);
      await pumpEventQueue();

      cubit.setTab(RemindersTab.completed);

      final state = cubit.state as RemindersAvailable;
      expect(state.tab, RemindersTab.completed);
      expect(state.visible, state.completed);
    });

    test('is a no-op before the list has loaded', () {
      cubit.setTab(RemindersTab.missed);

      expect(cubit.state, isA<RemindersLoading>());
    });

    test('keeps the selected tab across a live update', () async {
      cubit.start();
      repository.emit([]);
      await pumpEventQueue();
      cubit.setTab(RemindersTab.missed);

      repository.emit([fakeReminder()]);
      await pumpEventQueue();

      expect((cubit.state as RemindersAvailable).tab, RemindersTab.missed);
    });
  });
}
