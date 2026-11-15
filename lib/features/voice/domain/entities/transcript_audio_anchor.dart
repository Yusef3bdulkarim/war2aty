/// A moment where the read's transcription and its audio were known to be in
/// step, because one wire frame carried both (F37-T07).
///
/// This exists because the two arrive interleaved but not in lockstep: audio
/// runs ahead of its transcription, and the spike measured a 26-second read
/// delivered in 11–13 seconds. Counting every byte received so far at the
/// moment a *lone* transcript delta lands therefore measures **arrival** order,
/// not speech time, and would place a card seconds away from where it is
/// spoken. A frame that carries both is the only place the service itself ties
/// the two together, so those frames — and nothing else — become anchors.
///
/// Both fields are **cumulative**, not deltas: an anchor is then independently
/// meaningful, a frame the caller never saw costs accuracy rather than
/// correctness, and the aligner never has to re-accumulate a stream it did not
/// watch.
final class TranscriptAudioAnchor {
  const TranscriptAudioAnchor({
    required this.transcriptSoFar,
    required this.audioBytesSoFar,
  });

  /// Everything the service had transcribed of its own speech up to and
  /// including this frame.
  ///
  /// Never logged: these are the paper's own words (CLAUDE.md §7).
  final String transcriptSoFar;

  /// How many bytes of PCM had been handed to the sink up to and including this
  /// frame. Becomes a position on the audio's timeline through `PcmFormat`,
  /// which is the one place that arithmetic lives.
  final int audioBytesSoFar;

  @override
  bool operator ==(Object other) =>
      other is TranscriptAudioAnchor &&
      other.transcriptSoFar == transcriptSoFar &&
      other.audioBytesSoFar == audioBytesSoFar;

  @override
  int get hashCode => Object.hash(transcriptSoFar, audioBytesSoFar);

  /// Describes the transcription by size, never by its text.
  @override
  String toString() =>
      'TranscriptAudioAnchor(${transcriptSoFar.length} chars, '
      '$audioBytesSoFar bytes)';
}
