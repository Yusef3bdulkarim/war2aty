/// Watches how long live edge detection is taking and decides when to give up
/// on it (F16-T09).
///
/// Continuous per-frame work on a preview is the classic source of heat and
/// battery drain, and a phone that cannot keep up would show a guide lagging
/// behind the paper — worse than no guide at all. When that happens the
/// detector is switched off **silently** (F16 locked decision #4): the guide
/// simply stops appearing, and the user is told nothing.
///
/// Pure Dart, no clock of its own — durations are handed in — so every
/// threshold is testable without waiting for real time.
final class DetectionBudget {
  DetectionBudget({
    this.budget = const Duration(milliseconds: 120),
    this.windowSize = 10,
    this.consecutiveLateLimit = 5,
  });

  /// What one detection is allowed to take. Matches the frame throttle's
  /// interval (F16-T04): past this, detections cannot keep up with the frames
  /// being offered no matter how many are dropped.
  final Duration budget;

  /// How many recent detections the median is taken over.
  final int windowSize;

  /// How many detections in a row may each take more than twice the budget
  /// before detection is abandoned.
  final int consecutiveLateLimit;

  final List<int> _recent = [];
  int _consecutiveLate = 0;

  /// Times taken by the last [windowSize] detections, oldest first, in
  /// microseconds — exposed for the device pass to report (F16-T10).
  List<int> get recentMicroseconds => List.unmodifiable(_recent);

  void record(Duration elapsed) {
    _recent.add(elapsed.inMicroseconds);
    if (_recent.length > windowSize) _recent.removeAt(0);

    if (elapsed.inMicroseconds > budget.inMicroseconds * 2) {
      _consecutiveLate++;
    } else {
      _consecutiveLate = 0;
    }
  }

  /// Whether this phone should stop trying.
  ///
  /// Two conditions, because a uniformly slow device and one that has just
  /// started thermally throttling do not look alike: a median over a full
  /// window that is over budget catches the first, and a short run of very
  /// late frames catches the second before it has had time to move the
  /// median.
  bool get shouldDisable {
    if (_consecutiveLate >= consecutiveLateLimit) return true;
    if (_recent.length < windowSize) return false;
    return _median > budget.inMicroseconds;
  }

  int get _median {
    final sorted = [..._recent]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }

  /// Forgets everything. Called when the camera reopens, so a phone that has
  /// cooled down — or a session that was slow for an unrelated reason — gets
  /// another chance; the cost of being wrong is only a guide that never
  /// appears.
  void reset() {
    _recent.clear();
    _consecutiveLate = 0;
  }
}
