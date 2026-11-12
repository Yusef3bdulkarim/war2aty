import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';

void main() {
  group('the format Gemini Live streams', () {
    test('is the 24 kHz 16-bit mono the spike measured', () {
      expect(PcmFormat.geminiLive.sampleRate, 24000);
      expect(PcmFormat.geminiLive.channels, 1);
      expect(PcmFormat.geminiLive.bitsPerSample, 16);
    });

    test('runs at 48,000 bytes a second', () {
      expect(PcmFormat.geminiLive.bytesPerSecond, 48000);
    });
  });

  group('turning a byte offset into a moment in the reading', () {
    test('a second of audio is a second long', () {
      expect(
        PcmFormat.geminiLive.durationOfBytes(48000),
        const Duration(seconds: 1),
      );
    });

    test('no bytes is no time', () {
      expect(PcmFormat.geminiLive.durationOfBytes(0), Duration.zero);
    });

    test(
      'a 75-second page is ~3.6 MB, which is why the audio is compressed',
      () {
        expect(PcmFormat.geminiLive.durationOfBytes(3600000).inSeconds, 75);
      },
    );

    test(
      'keeps sub-millisecond precision, so a span boundary is not quantised',
      () {
        // 48 bytes is exactly 1 ms, so 24 bytes must not round away to zero.
        expect(
          PcmFormat.geminiLive.durationOfBytes(24),
          const Duration(microseconds: 500),
        );
      },
    );

    test('scales with the format rather than assuming 24 kHz', () {
      const telephone = PcmFormat(
        sampleRate: 8000,
        channels: 1,
        bitsPerSample: 16,
      );
      expect(telephone.bytesPerSecond, 16000);
      expect(telephone.durationOfBytes(16000), const Duration(seconds: 1));
    });
  });

  group('equality', () {
    test('two identical formats are the same value', () {
      expect(
        const PcmFormat(sampleRate: 24000, channels: 1, bitsPerSample: 16),
        PcmFormat.geminiLive,
      );
      expect(
        const PcmFormat(
          sampleRate: 24000,
          channels: 1,
          bitsPerSample: 16,
        ).hashCode,
        PcmFormat.geminiLive.hashCode,
      );
    });

    test('a different sample rate is a different format', () {
      expect(
        const PcmFormat(sampleRate: 16000, channels: 1, bitsPerSample: 16),
        isNot(PcmFormat.geminiLive),
      );
    });
  });
}
