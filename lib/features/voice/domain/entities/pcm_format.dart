/// The shape of the raw audio the voice service streams (F37).
///
/// Shared by the playback sink and the encoder because both have to agree on
/// it, and because it is what converts a byte count into a duration — the one
/// arithmetic the whole timing design rests on.
final class PcmFormat {
  const PcmFormat({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
  });

  /// What Gemini Live emits: 24 kHz, 16-bit, mono.
  ///
  /// Measured in F36-T02's spike, not assumed. At 48,000 bytes a second this is
  /// also where the ~0.3 MB-per-paper audio budget and the 850-character page
  /// cap come from (`docs/API_CONTRACT.md` §33.3).
  static const PcmFormat geminiLive = PcmFormat(
    sampleRate: 24000,
    channels: 1,
    bitsPerSample: 16,
  );

  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  int get bytesPerSecond => sampleRate * channels * (bitsPerSample ~/ 8);

  /// How long [byteCount] bytes of this format take to speak.
  ///
  /// Microseconds rather than milliseconds so that a span boundary computed
  /// from a byte offset does not quantise onto a 1 ms grid; at 48 bytes a
  /// millisecond the rounding would otherwise be visible in a card span.
  Duration durationOfBytes(int byteCount) =>
      Duration(microseconds: byteCount * 1000000 ~/ bytesPerSecond);

  @override
  bool operator ==(Object other) =>
      other is PcmFormat &&
      other.sampleRate == sampleRate &&
      other.channels == channels &&
      other.bitsPerSample == bitsPerSample;

  @override
  int get hashCode => Object.hash(sampleRate, channels, bitsPerSample);

  @override
  String toString() =>
      'PcmFormat(${sampleRate}Hz, ${channels}ch, ${bitsPerSample}bit)';
}
