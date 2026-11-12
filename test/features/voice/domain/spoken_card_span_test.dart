import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';

SpokenCardSpan _span({
  String id = 'segment',
  int fromMs = 0,
  int toMs = 1000,
  bool exact = true,
}) => SpokenCardSpan(
  segmentId: id,
  start: Duration(milliseconds: fromMs),
  end: Duration(milliseconds: toMs),
  exact: exact,
);

void main() {
  group('how long a segment is spoken for', () {
    test('is the distance between its ends', () {
      expect(
        _span(fromMs: 2000, toMs: 5500).duration,
        const Duration(milliseconds: 3500),
      );
    });
  });

  group('deciding which segment is being spoken', () {
    test('the start of a span is inside it', () {
      expect(
        _span(
          fromMs: 1000,
          toMs: 2000,
        ).contains(const Duration(milliseconds: 1000)),
        isTrue,
      );
    });

    test('the end of a span is NOT inside it', () {
      // Half-open on purpose: adjacent spans share a boundary, and a position
      // landing on it must highlight exactly one card, not two.
      expect(
        _span(
          fromMs: 1000,
          toMs: 2000,
        ).contains(const Duration(milliseconds: 2000)),
        isFalse,
      );
    });

    test('a position before the span is outside it', () {
      expect(_span(fromMs: 1000, toMs: 2000).contains(Duration.zero), isFalse);
    });

    test('adjacent spans never both claim the same moment', () {
      final first = _span(id: 'explain', toMs: 1500);
      final second = _span(id: 'todo', fromMs: 1500, toMs: 2500);
      const boundary = Duration(milliseconds: 1500);

      final claiming = [first, second].where((s) => s.contains(boundary));

      expect(claiming.map((s) => s.segmentId), ['todo']);
    });
  });

  group('whether a span was measured or guessed', () {
    test('an interpolated span is not equal to a measured one', () {
      // The flag is the whole point of the type: F40 must be able to tell a
      // span that came from the transcript from one derived from character
      // counts, so it can never be dropped by an equality that ignores it.
      expect(_span(exact: false), isNot(_span()));
    });

    test('two spans agreeing on everything are the same value', () {
      expect(_span(), _span());
      expect(_span().hashCode, _span().hashCode);
    });

    test('a span for another segment is a different value', () {
      expect(_span(id: 'date'), isNot(_span(id: 'todo')));
    });
  });
}
