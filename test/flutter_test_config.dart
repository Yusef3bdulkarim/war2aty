import 'dart:async';

import 'package:timezone/data/latest.dart' as tzdata;

/// Flutter's test runner picks this file up automatically and wraps every
/// test file under `test/` with it.
///
/// `cairoInstant` (`core/time/cairo_day.dart`) resolves `Africa/Cairo`
/// through the `timezone` package's IANA data, which the app itself loads
/// once at bootstrap (`FlutterLocalNotificationsPort.initialize()`). Tests
/// never run that bootstrap step, so anything that reaches `cairoInstant` —
/// directly, or via `Reminder.eventInstant` / `ReminderFormState.eventInstant`
/// — needs the same data loaded first. Doing it once here means no individual
/// test file has to remember to.
FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  tzdata.initializeTimeZones();
  await testMain();
}
