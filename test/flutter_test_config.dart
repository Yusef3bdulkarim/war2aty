import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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
  await _loadCairo();
  await testMain();
}

/// Registers the real Cairo font with the test binding (F27-T15).
///
/// Without this, every widget test lays text out in Flutter's placeholder
/// test font, whose glyphs are all one em wide. Cairo's average advance is
/// closer to half that, so text measured about **twice as wide as it really
/// is** — which made every layout assertion in the suite, including the
/// large-text ones, measure a font the app never ships. The layout audit in
/// `support/ui_audit.dart` could not tell a real overflow from that artefact.
///
/// This has to happen here rather than inside a test: `FontLoader.load`
/// awaits real file I/O, and a `testWidgets` body runs in a `FakeAsync` zone
/// where that future never completes.
Future<void> _loadCairo() async {
  final bytes = await File('assets/fonts/Cairo.ttf').readAsBytes();
  await (FontLoader(
    'Cairo',
  )..addFont(Future.value(bytes.buffer.asByteData()))).load();
}
