import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/presentation/cubit/detection_budget.dart';

void main() {
  // The production default, restated so the fixtures below are readable.
  const budget = Duration(milliseconds: 120);
  const fast = Duration(milliseconds: 40);
  const slow = Duration(milliseconds: 200);
  const veryLate = Duration(milliseconds: 400);

  DetectionBudget fresh() => DetectionBudget(budget: budget);

  void feed(DetectionBudget b, Duration each, int times) {
    for (var i = 0; i < times; i++) {
      b.record(each);
    }
  }

  test('a phone comfortably inside the budget is never disabled', () {
    final b = fresh();

    feed(b, fast, 50);

    expect(b.shouldDisable, isFalse);
  });

  test('nothing is decided before a full window has been seen', () {
    final b = fresh();

    feed(b, slow, b.windowSize - 1);

    expect(b.shouldDisable, isFalse);
  });

  test('a median over budget across a full window disables', () {
    final b = fresh();

    feed(b, slow, b.windowSize);

    expect(b.shouldDisable, isTrue);
  });

  test('a run of very late detections disables before the median moves', () {
    final b = fresh();

    // Not even a full window yet — this is the thermal-throttling case, which
    // must be caught before it has had time to drag the median with it.
    feed(b, veryLate, b.consecutiveLateLimit);

    expect(b.shouldDisable, isTrue);
  });

  test('a single outlier in an otherwise fast window does not disable', () {
    final b = fresh();

    feed(b, fast, b.windowSize - 1);
    b.record(veryLate);

    expect(b.shouldDisable, isFalse);
  });

  test('a fast detection breaks a run of late ones', () {
    final b = fresh();

    feed(b, veryLate, b.consecutiveLateLimit - 1);
    b.record(fast);
    feed(b, veryLate, b.consecutiveLateLimit - 1);

    expect(b.shouldDisable, isFalse);
  });

  test('the window forgets old detections', () {
    final b = fresh();

    feed(b, slow, b.windowSize);
    expect(b.shouldDisable, isTrue);

    // The phone recovered; once the slow ones have aged out of the window the
    // median is healthy again.
    feed(b, fast, b.windowSize);

    expect(b.shouldDisable, isFalse);
  });

  test('reset clears both conditions', () {
    final b = fresh();

    feed(b, veryLate, b.windowSize);
    expect(b.shouldDisable, isTrue);

    b.reset();

    expect(b.shouldDisable, isFalse);
    expect(b.recentMicroseconds, isEmpty);
  });

  test('recent timings are reported oldest first for the device pass', () {
    final b = fresh();

    b.record(const Duration(milliseconds: 10));
    b.record(const Duration(milliseconds: 20));

    expect(b.recentMicroseconds, [10000, 20000]);
  });
}
