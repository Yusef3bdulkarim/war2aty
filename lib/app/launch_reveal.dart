import 'package:flutter/foundation.dart';

/// Coordinates the end of the launch (F27-P01).
///
/// The splash fades off the app only once the first screen has the content it
/// opens with, so that screen's first build and its first data never land
/// while something on screen is moving. Work that would compete with the fade
/// — opening the reminder a notification tap launched the app for — waits
/// until [revealed].
final class LaunchReveal {
  bool _contentReady = false;
  final ValueNotifier<bool> _revealed = ValueNotifier(false);

  /// Whether the first screen has its content: Home once each of its sections
  /// has loaded, a static first-run page as soon as it is built.
  bool get contentReady => _contentReady;

  /// Called by the first screen. Only sets a flag — safe from a build.
  void markContentReady() => _contentReady = true;

  /// Whether the splash has finished fading off the app.
  ValueListenable<bool> get revealed => _revealed;

  void markRevealed() => _revealed.value = true;
}
