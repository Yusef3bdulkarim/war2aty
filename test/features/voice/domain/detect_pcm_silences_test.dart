import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/usecases/detect_pcm_silences.dart';

void main() {
  const detect = DetectPcmSilences();
  const format = PcmFormat.geminiLive; // 24 kHz, 16-bit, mono → 48 000 B/s

  /// Builds a PCM buffer from a sequence of [_Segment]s, each either silent
  /// (zero samples) or speech (440 Hz sine wave at the given amplitude).
  Uint8List buildPcm(List<_Segment> segments) {
    final totalBytes = segments.fold<int>(
      0,
      (sum, s) => sum + s.durationMs * 48,
    );
    final bytes = Uint8List(totalBytes);
    var offset = 0;
    for (final segment in segments) {
      final sampleCount = segment.durationMs * 24; // 24 samples/ms
      for (var i = 0; i < sampleCount; i++) {
        int sample;
        if (segment.isSilence) {
          sample = segment.noiseAmplitude;
        } else {
          sample = (segment.amplitude * math.sin(2 * math.pi * 440 * i / 24000))
              .round();
        }
        bytes[offset] = sample & 0xFF;
        bytes[offset + 1] = (sample >> 8) & 0xFF;
        offset += 2;
      }
    }
    return bytes;
  }

  group('DetectPcmSilences', () {
    test('empty input yields no gaps', () {
      expect(detect(pcmBytes: Uint8List(0), format: format), isEmpty);
    });

    test('input smaller than one frame yields no gaps', () {
      expect(detect(pcmBytes: Uint8List(100), format: format), isEmpty);
    });

    test('all speech yields no gaps', () {
      final pcm = buildPcm([_Segment.speech(durationMs: 2000)]);
      expect(detect(pcmBytes: pcm, format: format), isEmpty);
    });

    test('all silence yields one gap spanning the buffer', () {
      final pcm = buildPcm([_Segment.silence(durationMs: 1000)]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(1));
      expect(gaps[0].duration.inMilliseconds, greaterThanOrEqualTo(990));
    });

    test('one silence gap between two speech segments', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(1));

      // The gap should be roughly at 500 ms, lasting ~400 ms.
      final gap = gaps[0];
      expect(gap.start.inMilliseconds, closeTo(500, 20));
      expect(gap.duration.inMilliseconds, closeTo(400, 20));
    });

    test('two silence gaps between three speech segments', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 300),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 300),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 300),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(2));
      expect(gaps[0].start.inMilliseconds, closeTo(300, 20));
      expect(gaps[1].start.inMilliseconds, closeTo(1000, 20));
    });

    test('short silence below minGap is not detected', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 200), // < 250 ms default
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, isEmpty);
    });

    test('custom minGap detects shorter pauses', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 150),
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(
        pcmBytes: pcm,
        format: format,
        minGap: const Duration(milliseconds: 100),
      );
      expect(gaps, hasLength(1));
    });

    test('noisy silence below threshold is still detected', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 400, noiseAmplitude: 100), // < 200
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(1));
    });

    test('noisy silence above threshold is not detected', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 400, noiseAmplitude: 300), // > 200
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, isEmpty);
    });

    test('silence at the start of the buffer is detected', () {
      final pcm = buildPcm([
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(1));
      expect(gaps[0].start.inMilliseconds, closeTo(0, 10));
    });

    test('silence at the end of the buffer is detected', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 400),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(1));
      expect(gaps[0].start.inMilliseconds, closeTo(500, 20));
    });

    test('midpoint sits at the centre of the gap', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(1));
      final mid = gaps[0].midpoint.inMilliseconds;
      expect(mid, closeTo(700, 20)); // 500 + 400/2 = 700
    });

    test('five-segment page: four boundaries found', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 1000),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 800),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 600),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 1200),
        _Segment.silence(durationMs: 400),
        _Segment.speech(durationMs: 500),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(4));
    });

    test(
      'internal sentence pause below minGap does not create false boundary',
      () {
        // A segment with an internal 200 ms pause between sentences.
        final pcm = buildPcm([
          _Segment.speech(durationMs: 400),
          _Segment.silence(durationMs: 200), // internal pause — below 250 ms
          _Segment.speech(durationMs: 400),
          _Segment.silence(durationMs: 400), // real boundary
          _Segment.speech(durationMs: 500),
        ]);
        final gaps = detect(pcmBytes: pcm, format: format);
        expect(gaps, hasLength(1), reason: 'only the real boundary');
      },
    );

    test('custom threshold changes what counts as silence', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 500, amplitude: 5000),
        _Segment.silence(durationMs: 400, noiseAmplitude: 300),
        _Segment.speech(durationMs: 500, amplitude: 5000),
      ]);
      // Default threshold 200 → not detected (300 > 200).
      expect(detect(pcmBytes: pcm, format: format), isEmpty);
      // Threshold 400 → detected (300 < 400).
      expect(
        detect(pcmBytes: pcm, format: format, threshold: 400),
        hasLength(1),
      );
    });

    test('SilenceGap equality and hashCode', () {
      const a = SilenceGap(
        start: Duration(milliseconds: 500),
        end: Duration(milliseconds: 900),
      );
      const b = SilenceGap(
        start: Duration(milliseconds: 500),
        end: Duration(milliseconds: 900),
      );
      const c = SilenceGap(
        start: Duration(milliseconds: 500),
        end: Duration(milliseconds: 1000),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('SilenceGap.toString does not leak audio content', () {
      const gap = SilenceGap(
        start: Duration(milliseconds: 500),
        end: Duration(milliseconds: 900),
      );
      expect(gap.toString(), contains('SilenceGap'));
      expect(gap.toString(), isNot(contains('pcm')));
    });

    test('gaps are returned in temporal order', () {
      final pcm = buildPcm([
        _Segment.speech(durationMs: 300),
        _Segment.silence(durationMs: 300),
        _Segment.speech(durationMs: 300),
        _Segment.silence(durationMs: 300),
        _Segment.speech(durationMs: 300),
      ]);
      final gaps = detect(pcmBytes: pcm, format: format);
      expect(gaps, hasLength(2));
      expect(gaps[0].start, lessThan(gaps[1].start));
    });
  });
}

/// A building block for synthetic PCM: either speech (a sine wave) or silence
/// (zero or low-amplitude constant samples).
class _Segment {
  const _Segment._({
    required this.durationMs,
    required this.isSilence,
    this.amplitude = 10000,
    this.noiseAmplitude = 0,
  });

  factory _Segment.speech({required int durationMs, int amplitude = 10000}) =>
      _Segment._(
        durationMs: durationMs,
        isSilence: false,
        amplitude: amplitude,
      );

  factory _Segment.silence({required int durationMs, int noiseAmplitude = 0}) =>
      _Segment._(
        durationMs: durationMs,
        isSilence: true,
        noiseAmplitude: noiseAmplitude,
      );

  final int durationMs;
  final bool isSilence;
  final int amplitude;
  final int noiseAmplitude;
}
