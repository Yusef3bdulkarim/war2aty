import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/chunk_text_for_speaking.dart';

/// F30-T15. Android refuses an utterance over 4000 characters by *parking*
/// the call — `flutter_tts` never answers it and no event ever arrives — so
/// a long paper used to hang the reader for the rest of the session (F30
/// RC-3). This is what keeps the engine from ever being handed one.
void main() {
  const chunk = ChunkTextForSpeaking();

  /// The three guarantees the queue leans on, asserted together because a
  /// cut that breaks any one of them breaks the reading rather than the
  /// wording: the offsets progress is measured by are sums of these lengths.
  void expectFaithfulChunking(List<String> chunks, String text, int limit) {
    expect(chunks.join(), text, reason: 'the pieces must rebuild the text');
    expect(chunks, isNotEmpty);
    expect(chunks.any((c) => c.isEmpty), isFalse, reason: 'no empty piece');
    expect(
      chunks.every((c) => c.length <= limit),
      isTrue,
      reason: 'every piece is short enough for the engine',
    );
  }

  group('ChunkTextForSpeaking · when nothing needs cutting', () {
    test('text inside the limit is one piece, untouched', () {
      expect(chunk('فاتورة كهرباء', limit: 4000), const ['فاتورة كهرباء']);
    });

    test('text exactly at the limit is still one piece', () {
      // The engine's own check is "longer than", so a text of exactly the
      // limit is accepted — cutting it would be an audible gap for nothing.
      final text = 'ا' * 100;

      expect(chunk(text, limit: 100), [text]);
    });

    test('a platform that declares no limit never gets a cut', () {
      // iOS does not implement the call at all.
      final text = 'ا' * 10000;

      expect(chunk(text, limit: null), [text]);
    });

    test('a nonsensical limit is read as no limit', () {
      final text = 'ا' * 50;

      expect(chunk(text, limit: 0), [text]);
      expect(chunk(text, limit: -1), [text]);
    });
  });

  group('ChunkTextForSpeaking · where it cuts', () {
    test('after the last sentence that fits', () {
      const text = 'الفاتورة وصلت. لازم تتدفع قبل الخميس. شكرًا ليك.';

      final chunks = chunk(text, limit: 30);

      expect(chunks.first, 'الفاتورة وصلت.');
      expectFaithfulChunking(chunks, text, 30);
    });

    test('an Arabic question mark ends a sentence too', () {
      const text = 'إيه ده؟ دي فاتورة كهرباء';

      expect(chunk(text, limit: 10).first, 'إيه ده؟');
    });

    test('a line break is a sentence end', () {
      const text = 'المبلغ\n٥٠٠ جنيه';

      expect(chunk(text, limit: 8).first, 'المبلغ\n');
    });

    test('at the last space when no sentence ends in the window', () {
      const text = 'فاتورة كهرباء شهر مارس';

      final chunks = chunk(text, limit: 15);

      // The space stays with the piece before it, so no utterance opens on
      // one — and the pieces still rebuild the text exactly.
      expect(chunks.first, 'فاتورة كهرباء ');
      expectFaithfulChunking(chunks, text, 15);
    });

    test('a stretch with neither is cut where the limit falls', () {
      // 4000 characters with no space in them is not a paper anyone will
      // photograph, but a cut that cannot be placed must still be made.
      final text = 'ا' * 25;

      final chunks = chunk(text, limit: 10);

      expect(chunks, ['ا' * 10, 'ا' * 10, 'ا' * 5]);
      expectFaithfulChunking(chunks, text, 10);
    });

    test('never inside a surrogate pair', () {
      // An emoji is two code units, and half of one is not a character —
      // the same boundary F30-T10's segmentation had to respect.
      const text = '😀😀😀😀';

      final chunks = chunk(text, limit: 3);

      expect(chunks, const ['😀', '😀', '😀', '😀']);
      expectFaithfulChunking(chunks, text, 3);
      expect(chunks.every((c) => c.runes.length == 1), isTrue);
    });
  });

  group('ChunkTextForSpeaking · a reading the size of a real paper', () {
    test('a long paper is cut into pieces the engine will take', () {
      // Android's actual ceiling, against a reading comfortably over it.
      const limit = 4000;
      final text = List.filled(400, 'ده سطر من ورقة طويلة جدًا.').join(' ');

      final chunks = chunk(text, limit: limit);

      expect(text.length, greaterThan(limit));
      expect(chunks.length, greaterThan(1));
      expectFaithfulChunking(chunks, text, limit);
      // Every cut landed on a sentence end, which is what keeps the gaps
      // between pieces from being heard as a word broken in half.
      for (final piece in chunks.take(chunks.length - 1)) {
        expect(piece.endsWith('.'), isTrue);
      }
    });

    test('the pieces are as long as they can be, not as many as possible', () {
      final text = '${'ا' * 9} ' * 10;

      final chunks = chunk(text, limit: 20);

      // Each piece carries two words rather than one: a greedy cut takes the
      // last break in the window, and every extra piece is another gap.
      expect(chunks.every((c) => c.length > 10), isTrue);
    });
  });
}
