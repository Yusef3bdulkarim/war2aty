import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/error_code.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';

/// CLAUDE.md §7: the paper's words never reach a log.
///
/// The voice types carry the explanation itself, and `toString()` is what a
/// stray interpolation or a crash report actually prints — so each one is
/// asserted to describe its payload by size rather than by content. Written as
/// a test because the leak it prevents is invisible in review: a default
/// `toString()` would simply print the sentence.
void main() {
  const sentence = 'فاتورة الكهربا بتاعتك 250 جنيه، آخر ميعاد 20 نوفمبر';

  group('a segment of the page', () {
    test('describes itself by length, never by its text', () {
      const segment = VoiceSegment(id: 'explain', text: sentence);

      expect(segment.toString(), isNot(contains(sentence)));
      expect(segment.toString(), isNot(contains('250')));
      expect(segment.toString(), isNot(contains('نوفمبر')));
    });

    test('still says enough to debug with — the id and the size', () {
      const segment = VoiceSegment(id: 'explain', text: sentence);

      expect(segment.toString(), contains('explain'));
      expect(segment.toString(), contains('${sentence.length}'));
    });
  });

  group("the service's transcription of its own speech", () {
    test('describes itself by length, never by its text', () {
      const delta = LiveTranscriptDelta(sentence);

      expect(delta.toString(), isNot(contains(sentence)));
      expect(delta.toString(), isNot(contains('250')));
      expect(delta.toString(), contains('${sentence.length}'));
    });
  });

  group('a chunk of audio', () {
    test('describes itself by byte count, never by its bytes', () {
      final chunk = LivePcmChunk(Uint8List.fromList([1, 2, 3, 4]));

      expect(chunk.toString(), contains('4 bytes'));
      expect(chunk.toString(), isNot(contains('[1, 2, 3, 4]')));
    });
  });

  group('a read that was not verbatim', () {
    test('logs a stable code, not the rate it measured', () {
      // The rate belongs in a field beside the code. Folding it in would mint
      // an unbounded set of codes and make the one thing worth counting — how
      // often a read is refused — impossible to count.
      expect(
        errorCodeOf(const VoiceReadNotVerbatimFailure(0.37)),
        'VOICE_READ_NOT_VERBATIM',
      );
      expect(
        errorCodeOf(const VoiceReadNotVerbatimFailure(0.91)),
        'VOICE_READ_NOT_VERBATIM',
      );
    });

    test('carries the measured rate for the retry decision', () {
      expect(const VoiceReadNotVerbatimFailure(0.37).wordErrorRate, 0.37);
      expect(
        const VoiceReadNotVerbatimFailure(0.37),
        isNot(const VoiceReadNotVerbatimFailure(0.91)),
      );
    });
  });

  group('a stream that died part-way', () {
    test('carries how much was heard, which decides restart vs fallback', () {
      // Live cannot replay a partial turn, so this number is the difference
      // between restarting the read and hearing the paper's opening twice.
      const early = VoiceStreamInterruptedFailure(Duration(seconds: 1));
      const late = VoiceStreamInterruptedFailure(Duration(seconds: 40));

      expect(early.heard, const Duration(seconds: 1));
      expect(early, isNot(late));
      expect(errorCodeOf(early), 'VOICE_STREAM_INTERRUPTED');
    });
  });
}
