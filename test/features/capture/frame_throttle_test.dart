import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/data/services/frame_throttle.dart';

void main() {
  late DateTime clock;
  FrameThrottle throttleAt(Duration minInterval) =>
      FrameThrottle(minInterval: minInterval, now: () => clock);

  setUp(() => clock = DateTime(2026, 8, 30, 12));

  test('admits the first frame', () {
    expect(throttleAt(const Duration(milliseconds: 120)).tryAcquire(), isTrue);
  });

  test('drops a frame while the previous detection is still running', () {
    final throttle = throttleAt(const Duration(milliseconds: 120));

    expect(throttle.tryAcquire(), isTrue);
    clock = clock.add(const Duration(seconds: 5));

    // Plenty of time has passed, but the slot is still held: a queue is
    // exactly what F16-T04 forbids.
    expect(throttle.tryAcquire(), isFalse);
    expect(throttle.isBusy, isTrue);
  });

  test('drops a frame that arrives inside the minimum interval', () {
    final throttle = throttleAt(const Duration(milliseconds: 120));

    expect(throttle.tryAcquire(), isTrue);
    throttle.release();
    clock = clock.add(const Duration(milliseconds: 119));

    expect(throttle.tryAcquire(), isFalse);
  });

  test('admits again once the interval has passed and the slot is free', () {
    final throttle = throttleAt(const Duration(milliseconds: 120));

    expect(throttle.tryAcquire(), isTrue);
    throttle.release();
    clock = clock.add(const Duration(milliseconds: 120));

    expect(throttle.tryAcquire(), isTrue);
  });

  test('reset forgets the previous stream entirely', () {
    final throttle = throttleAt(const Duration(milliseconds: 120));

    expect(throttle.tryAcquire(), isTrue);
    throttle.reset();

    expect(throttle.isBusy, isFalse);
    expect(throttle.tryAcquire(), isTrue);
  });

  test('a burst of frames admits exactly one', () {
    final throttle = throttleAt(const Duration(milliseconds: 120));

    final admitted = [
      for (var i = 0; i < 10; i++) throttle.tryAcquire(),
    ].where((a) => a).length;

    expect(admitted, 1);
  });
}
