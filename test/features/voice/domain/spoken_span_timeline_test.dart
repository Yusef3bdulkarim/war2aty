import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/usecases/spoken_span_timeline.dart';

/// The arithmetic both tiers' spans are built with (F37-T07, F37-T18).
///
/// Tested on its own because it is shared: a change made for the device tier
/// would otherwise silently move where the Live tier highlights, and the
/// partition invariant below is what F40 relies on to always have exactly one
/// answer to "which card is being read now".
void main() {
  group('interpolateAt', () {
    const xs = [0, 10, 30];
    const ys = [0, 100, 200];

    test('answers the nearest known end outside the points', () {
      expect(interpolateAt(xs, ys, -5), 0);
      expect(interpolateAt(xs, ys, 0), 0);
      expect(interpolateAt(xs, ys, 30), 200);
      expect(interpolateAt(xs, ys, 500), 200);
    });

    test('answers a known point exactly', () {
      expect(interpolateAt(xs, ys, 10), 100);
    });

    test('interpolates between two points, by their own slope', () {
      expect(interpolateAt(xs, ys, 5), 50);
      // The second interval is five times slower than the first, and the
      // interpolation follows it rather than the average.
      expect(interpolateAt(xs, ys, 20), 150);
    });

    test('takes the first of two points that share an x', () {
      // Two measurements of the same character offset at different times: the
      // earlier one wins, so a card is placed where it was first heard rather
      // than where it was last re-reported. The `run <= 0` guard in there is
      // defensive — the walk always stops at the first of a tie, so it can only
      // be reached by a caller passing a decreasing `xs`.
      expect(interpolateAt(const [0, 10, 10, 20], const [0, 1, 7, 9], 10), 1);
      expect(interpolateAt(const [0, 10, 10, 20], const [0, 1, 7, 9], 15), 8);
    });

    test('answers from a single point', () {
      expect(interpolateAt(const [4], const [9], 1), 9);
      expect(interpolateAt(const [4], const [9], 7), 9);
    });
  });

  group('partitionSpans', () {
    test('partitions the whole read, with no gap between two cards', () {
      final spans = partitionSpans(
        segmentIds: const ['a', 'b', 'c'],
        startMicros: const [0, 2000, 7000],
        exact: const [true, true, false],
        totalMicros: 10000,
      );

      expect(spans.map((span) => span.segmentId), ['a', 'b', 'c']);
      expect(spans[0].start, Duration.zero);
      expect(spans[0].end, spans[1].start);
      expect(spans[1].end, spans[2].start);
      expect(spans.last.end, const Duration(microseconds: 10000));
      expect(spans.map((span) => span.exact), [true, true, false]);
    });

    test('starts the first card with the read, whatever it was placed at', () {
      final spans = partitionSpans(
        segmentIds: const ['a', 'b'],
        startMicros: const [500, 4000],
        exact: const [true, true],
        totalMicros: 9000,
      );

      expect(spans.first.start, Duration.zero);
    });

    test('a card placed before the one in front of it comes out empty', () {
      final spans = partitionSpans(
        segmentIds: const ['a', 'b', 'c'],
        startMicros: const [0, 6000, 3000],
        exact: const [true, true, true],
        totalMicros: 10000,
      );

      expect(spans[1].start, const Duration(microseconds: 6000));
      expect(spans[2].start, const Duration(microseconds: 6000));
      expect(spans[2].duration, const Duration(microseconds: 4000));
      // A zero-length span contains nothing, which is the honest outcome.
      expect(spans[1].duration, Duration.zero);
      expect(spans[1].contains(const Duration(microseconds: 6000)), isFalse);
    });

    test('clamps a card placed past the end of the read', () {
      final spans = partitionSpans(
        segmentIds: const ['a', 'b'],
        startMicros: const [0, 99000],
        exact: const [false, false],
        totalMicros: 10000,
      );

      expect(spans[1].start, const Duration(microseconds: 10000));
      expect(spans[1].end, const Duration(microseconds: 10000));
    });

    test('a page with no cards has no spans', () {
      expect(
        partitionSpans(
          segmentIds: const [],
          startMicros: const [],
          exact: const [],
          totalMicros: 10000,
        ),
        isEmpty,
      );
    });

    test('a single card covers the whole read', () {
      final spans = partitionSpans(
        segmentIds: const ['only'],
        startMicros: const [0],
        exact: const [true],
        totalMicros: 10000,
      );

      expect(spans.single.start, Duration.zero);
      expect(spans.single.end, const Duration(microseconds: 10000));
    });
  });
}
