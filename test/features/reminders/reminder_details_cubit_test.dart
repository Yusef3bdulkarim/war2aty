import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/usecases/complete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/delete_reminder.dart';
import 'package:war2aty/core/reminders/usecases/snooze_reminder.dart';
import 'package:war2aty/core/reminders/usecases/watch_reminder.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_details_cubit.dart';
import 'package:war2aty/features/reminders/presentation/cubit/reminder_details_state.dart';

import '../../support/fakes.dart';

// F09-T12: the details screen's own cubit.
void main() {
  late FakeRemindersRepository remindersRepository;
  late FakeReminderScheduler scheduler;
  late ReminderDetailsCubit cubit;

  setUp(() {
    remindersRepository = FakeRemindersRepository();
    scheduler = FakeReminderScheduler();
    cubit = ReminderDetailsCubit(
      WatchReminder(remindersRepository),
      CompleteReminder(remindersRepository, scheduler),
      SnoozeReminder(remindersRepository, scheduler),
      DeleteReminder(remindersRepository, scheduler),
    );
  });
  tearDown(() async {
    await cubit.close();
    await remindersRepository.dispose();
  });

  test('starts loading', () {
    expect(cubit.state, isA<ReminderDetailsLoading>());
  });

  test('reflects the reminder once the stream answers', () async {
    cubit.start('r1');
    remindersRepository.emitReminder('r1', fakeReminder());
    await pumpEventQueue();

    final state = cubit.state as ReminderDetailsAvailable;
    expect(state.reminder.id, 'r1');
  });

  test('start is safe to call twice', () async {
    cubit
      ..start('r1')
      ..start('r1');
    remindersRepository.emitReminder('r1', fakeReminder());
    await pumpEventQueue();

    expect(cubit.state, isA<ReminderDetailsAvailable>());
  });

  test('a null reminder surfaces as not found', () async {
    cubit.start('missing');
    remindersRepository.emitReminder('missing', null);
    await pumpEventQueue();

    expect(cubit.state, isA<ReminderDetailsNotFound>());
  });

  test('a read failure surfaces as unavailable', () async {
    cubit.start('r1');
    remindersRepository.emitReminderFailure('r1');
    await pumpEventQueue();

    expect(cubit.state, isA<ReminderDetailsUnavailable>());
  });

  group('complete', () {
    test('calls through and reports success', () async {
      cubit.start('r1');
      remindersRepository.emitReminder('r1', fakeReminder());
      await pumpEventQueue();

      final ok = await cubit.complete();

      expect(ok, isTrue);
      expect(remindersRepository.lastCompletedId, 'r1');
    });

    test('reports failure without crashing', () async {
      remindersRepository.completeOutcome = const Err(LocalDatabaseFailure());
      cubit.start('r1');
      remindersRepository.emitReminder('r1', fakeReminder());
      await pumpEventQueue();

      final ok = await cubit.complete();

      expect(ok, isFalse);
    });

    test('is a no-op before the reminder has loaded', () async {
      final ok = await cubit.complete();

      expect(ok, isFalse);
      expect(remindersRepository.lastCompletedId, isNull);
    });
  });

  group('snooze', () {
    test('calls through with the new alert time', () async {
      final newTime = DateTime.utc(2026, 8, 26, 10);
      cubit.start('r1');
      remindersRepository.emitReminder('r1', fakeReminder());
      await pumpEventQueue();

      final ok = await cubit.snooze(newTime);

      expect(ok, isTrue);
      expect(remindersRepository.lastSnoozedId, 'r1');
      expect(remindersRepository.lastSnoozedTo, newTime);
    });
  });

  group('delete', () {
    test('calls through and reports success', () async {
      cubit.start('r1');
      remindersRepository.emitReminder('r1', fakeReminder());
      await pumpEventQueue();

      final ok = await cubit.delete();

      expect(ok, isTrue);
      expect(remindersRepository.lastDeletedId, 'r1');
    });
  });
}
