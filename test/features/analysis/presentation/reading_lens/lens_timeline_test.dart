import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_layout.dart';

const _pass = LensTimeline.pass;

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 1e-9));
  expect(actual.dy, closeTo(expected.dy, 1e-9));
}

void main() {
  group('LensTimeline.lensAt', () {
    test('starts on the letterhead and ends the pass where it began', () {
      _expectOffset(LensTimeline.lensAt(0), const Offset(224, 38));
      _expectOffset(LensTimeline.lensAt(_pass), const Offset(224, 38));
    });

    test('pauses on the title', () {
      for (final t in [0.45, 0.6, 0.8, 0.95]) {
        _expectOffset(LensTimeline.lensAt(t), LensTimeline.restingPoint);
      }
    });

    test('pauses on the key word', () {
      final key = PaperLayout.words.singleWhere((w) => w.isKey).rect.center;
      for (final t in [2.4, 2.55, 2.7]) {
        final lens = LensTimeline.lensAt(t);
        expect(lens.dx, closeTo(key.dx, 1e-9));
        expect(lens.dy, closeTo(key.dy, 1e-9));
      }
    });

    test('pauses on each field', () {
      for (final (index, (start, end)) in LensTimeline.fieldPauses.indexed) {
        final field = PaperLayout.fields[index].box.center;
        for (final t in [start, (start + end) / 2, end]) {
          _expectOffset(LensTimeline.lensAt(t), field);
        }
      }
    });

    test('reads each line right to left', () {
      // Along the three body lines the lens only ever moves leftwards.
      for (final (from, to) in [(1.25, 1.85), (2.7, 3.05), (3.3, 3.9)]) {
        var previous = LensTimeline.lensAt(from).dx;
        for (var t = from + 0.01; t <= to; t += 0.01) {
          final x = LensTimeline.lensAt(t).dx;
          expect(x, lessThanOrEqualTo(previous + 1e-9), reason: 't = $t');
          previous = x;
        }
      }
    });

    test('eases: slow near a waypoint, fastest halfway', () {
      // The first body line, 1.25 → 1.85 s.
      final startStep =
          LensTimeline.lensAt(1.26).dx - LensTimeline.lensAt(1.25).dx;
      final midStep =
          LensTimeline.lensAt(1.56).dx - LensTimeline.lensAt(1.55).dx;
      expect(midStep.abs(), greaterThan(startStep.abs() * 10));
    });

    test('repeats every pass', () {
      for (final t in [0.3, 1.7, 2.5, 4.4, 5.5]) {
        _expectOffset(LensTimeline.lensAt(t + _pass), LensTimeline.lensAt(t));
        _expectOffset(
          LensTimeline.lensAt(t + 3 * _pass),
          LensTimeline.lensAt(t),
        );
      }
    });

    test('stays on the paper', () {
      for (var t = 0.0; t <= _pass; t += 0.01) {
        final lens = LensTimeline.lensAt(t);
        expect(
          (Offset.zero & PaperLayout.size).contains(lens),
          isTrue,
          reason: 't = $t',
        );
      }
    });
  });

  group('LensTimeline passes', () {
    test('passOf and timeInPass split the clock into passes', () {
      expect(LensTimeline.passOf(0), 0);
      expect(LensTimeline.passOf(_pass - 0.001), 0);
      expect(LensTimeline.passOf(_pass), 1);
      expect(LensTimeline.passOf(3 * _pass + 1), 3);
      expect(LensTimeline.timeInPass(_pass + 1.5), closeTo(1.5, 1e-9));
    });
  });

  group('LensTimeline.stepAt', () {
    test('changes caption exactly at each boundary', () {
      const cases = [
        (0.0, 0),
        (1.59, 0),
        (1.6, 1),
        (3.89, 1),
        (3.9, 2),
        (5.99, 2),
        (6.0, 3),
        (9.99, 3),
        (10.0, 4),
        (14.99, 4),
        (15.0, 5),
        (25.0, 5),
      ];
      for (final (seconds, step) in cases) {
        expect(LensTimeline.stepAt(seconds), step, reason: '$seconds s');
      }
    });

    test('the long subline and the long-wait announcement fall on steps', () {
      expect(
        LensTimeline.stepStarts,
        containsAll([LensTimeline.longSublineAt, LensTimeline.longWaitAt]),
      );
    });
  });

  group('LensTimeline.wordReadAt', () {
    test('has one time per word, all inside the pass', () {
      expect(LensTimeline.wordReadAt, hasLength(PaperLayout.words.length));
      for (final at in LensTimeline.wordReadAt) {
        expect(at, inInclusiveRange(0, _pass));
      }
    });

    test('reads the body line by line, right to left, then the fields', () {
      final times = LensTimeline.wordReadAt;
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]), reason: 'word $i');
      }
    });

    test('each word is under the lens when it is read', () {
      for (final (i, word) in PaperLayout.words.indexed) {
        final lens = LensTimeline.lensAt(LensTimeline.wordReadAt[i]);
        expect(
          LensTimeline.distanceToRect(lens, word.rect),
          lessThan(LensTimeline.litDistance),
          reason: 'word $i',
        );
      }
    });

    test('the key word is read when the lens reaches it', () {
      final key = PaperLayout.words.indexWhere((w) => w.isKey);
      expect(
        LensTimeline.wordReadAt[key],
        lessThanOrEqualTo(LensTimeline.keyWordReachedAt),
      );
    });
  });

  group('LensTimeline.reviewChecks', () {
    test('come in the order the lens leaves each part', () {
      final times = [for (final c in LensTimeline.reviewChecks) c.at];
      expect(times, orderedEquals([...times]..sort()));
      expect(times.last, lessThan(_pass));
    });

    test('sit on the paper', () {
      for (final check in LensTimeline.reviewChecks) {
        final rect = check.topLeft & const Size.square(PaperLayout.checkSize);
        expect(
          (Offset.zero & PaperLayout.size).contains(rect.bottomRight),
          isTrue,
        );
      }
    });
  });

  group('LensTimeline.handleSwingAt', () {
    test('is still during a pause and bounded while moving', () {
      expect(LensTimeline.handleSwingAt(0.7), 0);
      for (var t = 0.0; t <= _pass; t += 0.05) {
        expect(
          LensTimeline.handleSwingAt(t).abs(),
          lessThanOrEqualTo(LensTimeline.handleSwingLimit),
        );
      }
    });

    test('swings with the direction of travel', () {
      // Mid first line the lens moves left (negative x speed).
      expect(LensTimeline.handleSwingAt(1.55), lessThan(0));
      // Mid carriage return, from the line's end back to the right.
      expect(LensTimeline.handleSwingAt(1.97), greaterThan(0));
    });
  });

  group('LensTimeline.distanceToRect', () {
    const rect = Rect.fromLTWH(10, 10, 20, 10);

    test('is 0 inside and measures to the nearest edge or corner outside', () {
      expect(LensTimeline.distanceToRect(const Offset(15, 15), rect), 0);
      expect(LensTimeline.distanceToRect(const Offset(35, 15), rect), 5);
      expect(LensTimeline.distanceToRect(const Offset(33, 24), rect), 5);
    });
  });

  group('PaperLayout.words', () {
    test('three lines of four, then two field values', () {
      expect(PaperLayout.words, hasLength(14));
      expect(PaperLayout.words.where((w) => w.isKey), hasLength(1));
    });

    test('each line runs right to left from the right margin', () {
      for (var line = 0; line < 3; line++) {
        final words = PaperLayout.words.sublist(line * 4, line * 4 + 4);
        expect(words.first.rect.right, 236);
        for (var i = 1; i < words.length; i++) {
          expect(words[i].rect.right, lessThan(words[i - 1].rect.left));
        }
      }
    });

    test('everything sits inside the paper', () {
      final paper = Offset.zero & PaperLayout.size;
      for (final word in PaperLayout.words) {
        expect(paper.intersect(word.rect), word.rect);
      }
      for (final field in PaperLayout.fields) {
        expect(paper.intersect(field.box), field.box);
        expect(field.box.intersect(field.label), field.label);
      }
    });
  });
}
