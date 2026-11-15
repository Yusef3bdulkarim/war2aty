/// One addressable piece of a page the voice reads (F37).
///
/// The spine takes a list of these, not the `explain-document` response: F37
/// shares no code with F36 and knows nothing about cards, titles or which of
/// them may be null. Mapping a response onto segments is the caller's job
/// (F38/F40), which is also what lets a saved paper, a fixture and a future
/// screen all drive the same reader.
///
/// [id] is opaque here and only has to be stable and unique within one page —
/// the caller gets it back on every `SpokenCardSpan` so it can match a span to
/// whatever it drew.
final class VoiceSegment {
  const VoiceSegment({required this.id, required this.text});

  final String id;

  /// Exactly what is to be spoken, already in the order the page reads.
  ///
  /// Never logged: this is document content (CLAUDE.md §7).
  final String text;

  @override
  bool operator ==(Object other) =>
      other is VoiceSegment && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);

  @override
  String toString() => 'VoiceSegment($id, ${text.length} chars)';
}
