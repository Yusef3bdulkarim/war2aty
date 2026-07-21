import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/reminders/reminder_scheduler.dart';
import 'package:war2aty/core/result/result.dart';

void main() {
  test('no-op scheduler reconciles nothing and succeeds', () async {
    const scheduler = NoopReminderScheduler();

    expect(await scheduler.reconcile(), const Ok<int, AppFailure>(0));
  });

  test('no-op scheduler is safe to call repeatedly', () async {
    const scheduler = NoopReminderScheduler();

    for (var i = 0; i < 3; i++) {
      expect(await scheduler.reconcile(), const Ok<int, AppFailure>(0));
    }
  });

  test('satisfies the ReminderScheduler contract', () {
    // Guards the launch hook: F09's real implementation must be substitutable.
    const ReminderScheduler scheduler = NoopReminderScheduler();

    expect(scheduler, isA<ReminderScheduler>());
  });
}
