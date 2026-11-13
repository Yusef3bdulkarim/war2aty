import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';
import 'package:war2aty/features/voice/domain/usecases/build_voice_turn_text.dart';

void main() {
  const build = BuildVoiceTurnText();

  group('BuildVoiceTurnText', () {
    test('empty segments yield empty text and no offsets', () {
      final result = build([]);
      expect(result.text, '');
      expect(result.offsets, isEmpty);
    });

    test('single segment yields its text verbatim, no separator', () {
      final result = build([
        const VoiceSegment(id: 'a', text: 'فاتورة كهرباء'),
      ]);
      expect(result.text, 'فاتورة كهرباء');
      expect(result.offsets, hasLength(1));
      expect(result.offsets[0].segmentId, 'a');
      expect(result.offsets[0].start, 0);
      expect(result.offsets[0].end, 'فاتورة كهرباء'.length);
      expect(
        result.text.substring(result.offsets[0].start, result.offsets[0].end),
        'فاتورة كهرباء',
      );
    });

    test('two segments are separated by a full stop and blank line', () {
      final result = build([
        const VoiceSegment(id: 'a', text: 'أولاً'),
        const VoiceSegment(id: 'b', text: 'ثانياً'),
      ]);
      expect(result.text, 'أولاً${BuildVoiceTurnText.separator}ثانياً');
      expect(result.text.contains('.\n\n'), isTrue);
    });

    test('six-card page yields exact per-segment offsets', () {
      final segments = [
        const VoiceSegment(id: 'title', text: 'فاتورة كهرباء'),
        const VoiceSegment(id: 'summary', text: 'دي فاتورة كهرباء الشهر ده'),
        const VoiceSegment(id: 'amount', text: 'المبلغ المطلوب 150 جنيه'),
        const VoiceSegment(id: 'due', text: 'آخر ميعاد 20 نوفمبر'),
        const VoiceSegment(id: 'action', text: 'روح ادفع في أي فرع'),
        const VoiceSegment(id: 'note', text: 'لو ماتدفعش هيتقطع'),
      ];

      final result = build(segments);

      expect(result.offsets, hasLength(6));

      for (var i = 0; i < segments.length; i++) {
        final offset = result.offsets[i];
        expect(offset.segmentId, segments[i].id);
        expect(offset.length, segments[i].text.length);
        expect(
          result.text.substring(offset.start, offset.end),
          segments[i].text,
          reason: 'offset for ${segments[i].id} must extract the original text',
        );
      }

      // Offsets are non-overlapping and ordered.
      for (var i = 1; i < result.offsets.length; i++) {
        expect(
          result.offsets[i].start,
          greaterThan(result.offsets[i - 1].end),
          reason:
              'segment ${result.offsets[i].segmentId} must start after '
              '${result.offsets[i - 1].segmentId} ends (separator between them)',
        );
      }

      // Every gap between segments is exactly the separator.
      for (var i = 0; i < result.offsets.length - 1; i++) {
        final gap = result.text.substring(
          result.offsets[i].end,
          result.offsets[i + 1].start,
        );
        expect(gap, BuildVoiceTurnText.separator);
      }
    });

    test('separator contains a full stop so Live pauses', () {
      expect(BuildVoiceTurnText.separator, contains('.'));
    });

    test('separator contains a blank line', () {
      expect(BuildVoiceTurnText.separator, contains('\n\n'));
    });

    test('segment text with leading/trailing whitespace is preserved', () {
      final result = build([const VoiceSegment(id: 'a', text: '  مسافات  ')]);
      expect(
        result.text.substring(result.offsets[0].start, result.offsets[0].end),
        '  مسافات  ',
      );
    });

    test(
      'empty-text segments get zero-length offsets at correct positions',
      () {
        final result = build([
          const VoiceSegment(id: 'a', text: 'قبل'),
          const VoiceSegment(id: 'empty', text: ''),
          const VoiceSegment(id: 'b', text: 'بعد'),
        ]);

        expect(result.offsets, hasLength(3));

        final empty = result.offsets[1];
        expect(empty.segmentId, 'empty');
        expect(empty.length, 0);
        expect(empty.start, empty.end);

        expect(
          result.text.substring(result.offsets[0].start, result.offsets[0].end),
          'قبل',
        );
        expect(
          result.text.substring(result.offsets[2].start, result.offsets[2].end),
          'بعد',
        );
      },
    );

    test('three segments: total length equals segments + separators', () {
      final segments = [
        const VoiceSegment(id: 'a', text: 'أ'),
        const VoiceSegment(id: 'b', text: 'ب'),
        const VoiceSegment(id: 'c', text: 'ج'),
      ];
      final result = build(segments);

      final expectedLength =
          segments.fold<int>(0, (s, seg) => s + seg.text.length) +
          BuildVoiceTurnText.separator.length * (segments.length - 1);
      expect(result.text.length, expectedLength);
    });

    test('VoiceTurnText.toString reports length, never content', () {
      final result = build([const VoiceSegment(id: 'a', text: 'سري')]);
      expect(result.toString(), contains('chars'));
      expect(result.toString(), isNot(contains('سري')));
    });

    test('SegmentCharOffset equality and hashCode', () {
      const a = SegmentCharOffset(segmentId: 'x', start: 0, end: 5);
      const b = SegmentCharOffset(segmentId: 'x', start: 0, end: 5);
      const c = SegmentCharOffset(segmentId: 'x', start: 0, end: 6);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
