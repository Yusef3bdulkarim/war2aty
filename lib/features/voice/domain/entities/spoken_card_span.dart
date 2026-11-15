/// When one segment of the page is spoken, on the audio's own timeline (F37).
///
/// Produced so the result screen (F40) can highlight and auto-scroll to the
/// segment being read, and jump to one the user taps.
///
/// [exact] is the honest part. A span is only exact when the segment's words
/// were actually found in the service's transcription of its own speech;
/// otherwise it is interpolated from the segment's share of the page's
/// characters. Alignment deliberately never fails a read, so the caller is told
/// which spans it can trust rather than being handed a guess dressed as a
/// measurement — a date read as «عشرين نوفمبر» when the page says
/// «20 نوفمبر» is the likeliest segment to land here, and the most important
/// one to not mis-highlight silently.
final class SpokenCardSpan {
  const SpokenCardSpan({
    required this.segmentId,
    required this.start,
    required this.end,
    required this.exact,
  });

  final String segmentId;
  final Duration start;
  final Duration end;
  final bool exact;

  Duration get duration => end - start;

  bool contains(Duration position) => position >= start && position < end;

  @override
  bool operator ==(Object other) =>
      other is SpokenCardSpan &&
      other.segmentId == segmentId &&
      other.start == start &&
      other.end == end &&
      other.exact == exact;

  @override
  int get hashCode => Object.hash(segmentId, start, end, exact);

  @override
  String toString() => 'SpokenCardSpan($segmentId, $start-$end, exact: $exact)';
}
