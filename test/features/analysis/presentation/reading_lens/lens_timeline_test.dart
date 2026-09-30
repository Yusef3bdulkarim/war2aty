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
    test('starts at the first line and ends the pass where it began', () {
      _expectOffset(LensTimeline.lensAt(0), const Offset(236, 96));
      _expectOffset(LensTimeline.lensAt(_pass), const Offset(236, 96));
    });

    test('pauses on each key word', () {
      final keys = PaperLayout.words.where((w) => w.isKey).toList();
      expect(keys, hasLength(2));
      for (final (key, times) in [
        (keys[0], [1.84, 2.0, 2.24]),
        (keys[1], [6.88, 7.1, 7.36]),
      ]) {
        for (final t in times) {
          _expectOffset(LensTimeline.lensAt(t), key.rect.center);
        }
      }
    });

    test('reads each line right to left at a steady speed', () {
      // The first line: 212 paper units in 1.2 s.
      final a = LensTimeline.lensAt(0.3).dx;
      final b = LensTimeline.lensAt(0.6).dx;
      final c = LensTimeline.lensAt(0.9).dx;
      expect(b, lessThan(a));
      expect(a - b, closeTo(b - c, 1e-9));
      expect(a - b, closeTo(212 / 1.2 * 0.3, 1e-9));
    });

    test('ends each line at the left margin when its check is due', () {
      for (final (line, end) in LensTimeline.lineEnds.indexed) {
        _expectOffset(
          LensTimeline.lensAt(end),
          Offset(24, PaperLayout.lineCentres[line]),
        );
      }
    });

    test('repeats every pass', () {
      for (final t in [0.3, 1.7, 2.5, 4.4, 7.0]) {
        _expectOffset(LensTimeline.lensAt(t + _pass), LensTimeline.lensAt(t));
        _expectOffset(
          LensTimeline.lensAt(t + 3 * _pass),
          LensTimeline.lensAt(t),
        );
      }
    });

    test('stays on the paper', () {
      for (var t = 0.0; t <= _pass; t += 0.01) {
        expect(
          (Offset.zero & PaperLayout.size).contains(LensTimeline.lensAt(t)),
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
        (1.89, 0),
        (1.9, 1),
        (3.79, 1),
        (3.8, 2),
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
    test('is when the lens centre crosses each word\'s middle', () {
      expect(LensTimeline.wordReadAt, hasLength(PaperLayout.words.length));
      for (final (i, word) in PaperLayout.words.indexed) {
        _expectOffset(
          LensTimeline.lensAt(LensTimeline.wordReadAt[i]),
          word.rect.center,
        );
      }
    });

    test('reads the body line by line, right to left, then the field', () {
      final times = LensTimeline.wordReadAt;
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]), reason: 'word $i');
      }
    });

    test('a key word is read as the lens arrives, before its pause', () {
      final keys = [
        for (final (i, w) in PaperLayout.words.indexed)
          if (w.isKey) LensTimeline.wordReadAt[i],
      ];
      expect(keys[0], closeTo(1.84, 1e-9));
      expect(keys[1], closeTo(6.88, 1e-9));
    });
  });

  group('LensTimeline motion', () {
    test('the bob swings 2 each way over 1.3 s', () {
      expect(LensTimeline.bobAt(0), closeTo(-2, 1e-9));
      expect(LensTimeline.bobAt(1.3), closeTo(2, 1e-9));
      expect(LensTimeline.bobAt(2.6), closeTo(-2, 1e-9));
      expect(LensTimeline.bobAt(0.65), closeTo(0, 1e-9));
    });

    test('the paper floats 5 up and back every 5 s', () {
      expect(LensTimeline.floatAt(0), 0);
      expect(LensTimeline.floatAt(2.5), closeTo(-5, 1e-9));
      expect(LensTimeline.floatAt(5), closeTo(0, 1e-9));
    });

    test('the glint sweeps the first 35% of every 2.8 s', () {
      expect(LensTimeline.glintAt(0), 0);
      expect(LensTimeline.glintAt(0.49), closeTo(0.5, 1e-9));
      expect(LensTimeline.glintAt(1), isNull);
      expect(LensTimeline.glintAt(2.8 + 0.49), closeTo(0.5, 1e-9));
    });

    test('the light behind the paper echoes the lens, softer', () {
      _expectOffset(
        LensTimeline.spotlightFor(const Offset(236, 96)),
        const Offset(50, -40),
      );
      _expectOffset(
        LensTimeline.spotlightFor(const Offset(24, 222)),
        const Offset(-50, 20),
      );
      _expectOffset(
        LensTimeline.spotlightFor(LensTimeline.centre),
        Offset.zero,
      );
    });
  });

  group('PaperLayout', () {
    test('four body lines of four, then the field\'s label and value', () {
      expect(PaperLayout.words, hasLength(18));
      expect(PaperLayout.wordLines, hasLength(18));
      expect(PaperLayout.words.where((w) => w.isKey), hasLength(2));
      expect(PaperLayout.wordLines.last, 4);
    });

    test('each body line runs right to left from the right margin', () {
      for (var line = 0; line < 4; line++) {
        final words = PaperLayout.words.sublist(line * 4, line * 4 + 4);
        expect(words.first.rect.right, 236);
        for (var i = 1; i < words.length; i++) {
          expect(words[i].rect.right, lessThan(words[i - 1].rect.left));
        }
      }
    });

    test('everything sits inside the paper, the field\'s words in the box', () {
      final paper = Offset.zero & PaperLayout.size;
      for (final word in PaperLayout.words) {
        expect(paper.intersect(word.rect), word.rect);
      }
      for (final word in PaperLayout.words.sublist(16)) {
        expect(PaperLayout.field.intersect(word.rect), word.rect);
      }
      expect(paper.intersect(PaperLayout.stamp), PaperLayout.stamp);
    });
  });
}
