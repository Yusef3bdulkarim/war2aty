import 'dart:math' as math;
import 'dart:typed_data';

import '../entities/pcm_format.dart';

/// A silence gap found in PCM audio (F37-T14).
///
/// The gap is a contiguous run of frames whose RMS amplitude is below a
/// threshold, lasting at least a minimum duration. The [midpoint] is the
/// natural candidate for a segment boundary timestamp.
final class SilenceGap {
  const SilenceGap({required this.start, required this.end});

  final Duration start;
  final Duration end;

  Duration get duration => end - start;

  Duration get midpoint =>
      start + Duration(microseconds: duration.inMicroseconds ~/ 2);

  @override
  bool operator ==(Object other) =>
      other is SilenceGap && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SilenceGap($start–$end)';
}

/// Finds silence gaps in PCM audio that might correspond to segment boundaries
/// (F37-T14).
///
/// Scans 16-bit little-endian mono PCM for runs of consecutive frames where
/// the RMS amplitude stays below [defaultThreshold] for at least
/// [defaultMinGap]. Returns the gaps in temporal order.
///
/// Written as a probe for whether silence is a viable transcript-independent
/// source of segment boundaries. See T14's finding in the feature doc.
final class DetectPcmSilences {
  const DetectPcmSilences();

  /// RMS threshold below which a frame is considered silent.
  ///
  /// 16-bit audio spans ±32 767. An RMS of 200 is about −44 dBFS — well below
  /// conversational speech (~−20 dBFS, RMS ~3 000–10 000) but above
  /// quantisation noise. This is a design-time estimate: tuning it requires
  /// real Gemini Live audio, which T01 has not yet produced.
  static const int defaultThreshold = 200;

  /// Minimum gap duration to count as a segment boundary.
  static const Duration defaultMinGap = Duration(milliseconds: 250);

  /// The window over which RMS is computed.
  static const Duration frameSize = Duration(milliseconds: 10);

  List<SilenceGap> call({
    required Uint8List pcmBytes,
    required PcmFormat format,
    int threshold = defaultThreshold,
    Duration minGap = defaultMinGap,
  }) {
    final bytesPerFrame =
        format.bytesPerSecond *
        frameSize.inMicroseconds ~/
        Duration.microsecondsPerSecond;
    if (bytesPerFrame < 2 || pcmBytes.length < bytesPerFrame) return const [];

    final gaps = <SilenceGap>[];
    int? silenceStartByte;

    for (
      var offset = 0;
      offset + bytesPerFrame <= pcmBytes.length;
      offset += bytesPerFrame
    ) {
      final rms = _rmsOfFrame(pcmBytes, offset, bytesPerFrame);
      if (rms < threshold) {
        silenceStartByte ??= offset;
      } else {
        if (silenceStartByte != null) {
          _maybeAdd(gaps, silenceStartByte, offset, format, minGap);
          silenceStartByte = null;
        }
      }
    }

    if (silenceStartByte != null) {
      _maybeAdd(gaps, silenceStartByte, pcmBytes.length, format, minGap);
    }

    return gaps;
  }

  void _maybeAdd(
    List<SilenceGap> gaps,
    int startByte,
    int endByte,
    PcmFormat format,
    Duration minGap,
  ) {
    final start = format.durationOfBytes(startByte);
    final end = format.durationOfBytes(endByte);
    if (end - start >= minGap) {
      gaps.add(SilenceGap(start: start, end: end));
    }
  }

  double _rmsOfFrame(Uint8List bytes, int offset, int frameBytes) {
    final sampleCount = frameBytes ~/ 2;
    if (sampleCount == 0) return 0;

    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final byteIndex = offset + i * 2;
      final lo = bytes[byteIndex];
      final hi = bytes[byteIndex + 1];
      final sample = (hi << 8 | lo).toSigned(16);
      sumSquares += sample * sample;
    }
    return math.sqrt(sumSquares / sampleCount);
  }
}
