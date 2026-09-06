/// The gate that keeps live edge detection from ever falling behind the camera.
///
/// The preview delivers frames far faster than a detection can run, so this
/// admits one at a time and **drops** the rest (F16-T04) — never queues them.
/// Dropping is the whole point: a queue would grow without bound, spend memory
/// on frames the user has already moved past, and show a quad that lags the
/// preview.
///
/// Pure Dart with an injectable clock, so the timing is testable without
/// waiting for real time to pass.
final class FrameThrottle {
  FrameThrottle({
    this.minInterval = const Duration(milliseconds: 120),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The shortest gap between two admitted frames — roughly 8 per second,
  /// which is well past the point where the guide looks responsive, and a
  /// fraction of the work of processing every frame.
  final Duration minInterval;

  final DateTime Function() _now;

  DateTime? _lastAdmitted;
  bool _inFlight = false;

  /// Whether a detection is running right now.
  bool get isBusy => _inFlight;

  /// Claims the slot for one frame, or returns `false` if this frame should be
  /// dropped — either because the previous one is still being processed, or
  /// because it arrived inside [minInterval].
  ///
  /// Every `true` must be matched by exactly one [release].
  bool tryAcquire() {
    if (_inFlight) return false;

    final now = _now();
    final last = _lastAdmitted;
    if (last != null && now.difference(last) < minInterval) return false;

    _lastAdmitted = now;
    _inFlight = true;
    return true;
  }

  /// Frees the slot claimed by [tryAcquire].
  void release() => _inFlight = false;

  /// Forgets everything — used when the stream stops, so a stream restarted
  /// later is not throttled against the previous session's clock.
  void reset() {
    _inFlight = false;
    _lastAdmitted = null;
  }
}
