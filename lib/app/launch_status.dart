import 'package:flutter/foundation.dart';

/// The two facts the end of the launch turns on (F28-T07).
///
/// App-scoped and deliberately dumb: it holds no logic and decides nothing.
/// Three parts of the app need to agree about when the launch ends, and none
/// of them can see the others — the router knows when the first screen has its
/// content, the hand-off decides when to reveal it, and the notification opener
/// must not push a route until that is over. This is where they meet.
///
/// Replaces `LaunchReveal`, which did the same job for the splash that F28
/// deleted. The names changed with it: "reveal" described the old animation,
/// not the fact being reported.
final class LaunchStatus {
  bool _firstScreenReady = false;
  final ValueNotifier<bool> _handedOff = ValueNotifier(false);

  /// Whether the screen the app opens on has the content it opens with: Home
  /// once each of its sections has loaded, a static first-run page as soon as
  /// it is built.
  ///
  /// The hand-off waits for this so the launch screen never lifts on a
  /// half-drawn Home. It is a plain flag rather than a listenable because the
  /// hand-off is already checking every frame.
  bool get firstScreenReady => _firstScreenReady;

  /// Called by the first screen. Only sets a flag — safe to call from a build.
  void markFirstScreenReady() => _firstScreenReady = true;

  /// Whether the launch screen has finished fading off the app.
  ///
  /// Work that would compete with that fade waits for it: a reminder opened by
  /// the notification tap that launched the app would otherwise slide its page
  /// in underneath.
  ValueListenable<bool> get handedOff => _handedOff;

  void markHandedOff() => _handedOff.value = true;
}
