import '../entities/voice_segment.dart';

/// Assembles segments into a single turn for the Gemini Live session, and
/// records where each segment sits inside it (F37-T06).
///
/// Segments are separated by a blank line and a trailing full stop so the
/// voice actually pauses between them — without the full stop Live tends to
/// run them together. T14's silence detector and T18's device-TTS adapter
/// both consume the offsets this returns.
///
/// The offsets are character-level into the assembled [VoiceTurnText.text],
/// not byte-level, because [LiveClientContentDto] sends text as a JSON
/// string and the service counts characters, not UTF-8 bytes.
final class BuildVoiceTurnText {
  const BuildVoiceTurnText();

  /// The separator placed between consecutive segments.
  ///
  /// A full stop followed by a blank line: the stop tells Live the sentence
  /// ended (so it pauses), the blank line gives a visual break in logs, and
  /// together they produce a consistent ~400 ms gap in the audio.
  static const String separator = '.\n\n';

  VoiceTurnText call(List<VoiceSegment> segments) {
    if (segments.isEmpty) {
      return const VoiceTurnText(text: '', offsets: []);
    }

    final buffer = StringBuffer();
    final offsets = <SegmentCharOffset>[];

    for (var i = 0; i < segments.length; i++) {
      final start = buffer.length;
      buffer.write(segments[i].text);
      final end = buffer.length;

      offsets.add(
        SegmentCharOffset(segmentId: segments[i].id, start: start, end: end),
      );

      if (i < segments.length - 1) {
        buffer.write(separator);
      }
    }

    return VoiceTurnText(text: buffer.toString(), offsets: offsets);
  }
}

/// The turn text and where each segment sits inside it.
final class VoiceTurnText {
  const VoiceTurnText({required this.text, required this.offsets});

  /// The full text sent as the user turn to Gemini Live.
  ///
  /// Document content: never logged (CLAUDE.md §7).
  final String text;

  /// One entry per input segment, in the same order.
  final List<SegmentCharOffset> offsets;

  @override
  String toString() =>
      'VoiceTurnText(${text.length} chars, ${offsets.length} segments)';
}

/// Where one segment's text begins and ends inside the assembled turn.
///
/// Half-open: [start] is inclusive, [end] is exclusive, matching Dart's
/// `String.substring(start, end)`.
final class SegmentCharOffset {
  const SegmentCharOffset({
    required this.segmentId,
    required this.start,
    required this.end,
  });

  final String segmentId;

  /// Inclusive start index into [VoiceTurnText.text].
  final int start;

  /// Exclusive end index into [VoiceTurnText.text].
  final int end;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is SegmentCharOffset &&
      other.segmentId == segmentId &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(segmentId, start, end);

  @override
  String toString() => 'SegmentCharOffset($segmentId, $start..$end)';
}
