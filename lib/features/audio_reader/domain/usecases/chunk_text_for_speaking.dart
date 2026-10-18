/// Cuts a stretch of a reading into pieces the engine will actually take
/// (F30-T15).
///
/// Android's `TextToSpeech` refuses any utterance longer than
/// `getMaxSpeechInputLength()` — 4000 characters — and the refusal is the
/// worst-shaped one in the whole feature: `flutter_tts` parks the call
/// instead of answering it, no event is ever emitted, and the reading hangs
/// for the rest of the session (F30 RC-3). Nothing in the app had a guard, so
/// a long paper read through `StartRawReading` — the OCR review screen hands
/// over the whole recognised text — was one `speak` away from it.
///
/// Splitting is what removes the trigger. `ReadingQueue` already speaks a
/// reading as several utterances, one per language run, so a run too long for
/// the engine simply becomes more than one queue item; everything downstream
/// — the voice per item, the progress offsets, pause and resume — works on
/// the pieces exactly as it worked on the runs.
///
/// Where it cuts matters, because every cut is heard: the engine stops at the
/// end of one utterance and starts the next, so a cut in the middle of a word
/// is a word broken in half out loud. So the latest sentence end inside the
/// window is preferred, then the latest space, and only a stretch with
/// neither — 4000 characters without one space, which no paper produces — is
/// cut where the limit falls.
///
/// Synchronous and total, like `SegmentLanguageRuns` (F30-T10): slicing a
/// string that already exists cannot fail.
///
/// Guarantees, all of them asserted in tests because the queue leans on them
/// the same way it leans on the segmenter's:
///
/// * Concatenating every piece reproduces the input exactly — progress
///   offsets are sums of the lengths before each piece, so a lost or added
///   character would move the bar off the text.
/// * No piece is empty, and no piece is longer than the limit.
/// * No cut lands inside a surrogate pair.
final class ChunkTextForSpeaking {
  const ChunkTextForSpeaking();

  /// [text] in pieces of at most [limit] UTF-16 code units — the unit
  /// Android counts its own limit in, and the unit `String.length` is in.
  ///
  /// A `null` [limit] is a platform that declares no limit: iOS does not
  /// implement the call at all, and `AVSpeechSynthesizer` has no documented
  /// ceiling. Nothing is cut then, because an unnecessary cut is an audible
  /// gap for nothing.
  List<String> call(String text, {required int? limit}) {
    if (limit == null || limit <= 0 || text.length <= limit) return [text];

    final chunks = <String>[];
    var start = 0;
    while (text.length - start > limit) {
      final cut = _cut(text, start, start + limit);
      chunks.add(text.substring(start, cut));
      start = cut;
    }
    chunks.add(text.substring(start));
    return chunks;
  }

  /// Where to cut, somewhere in `(start, ceiling]`.
  ///
  /// Always past [start], so the caller's loop cannot spin: every tier below
  /// either lands on an index at or after [start] and cuts after it, or falls
  /// through to [ceiling], which is [start] plus the limit.
  static int _cut(String text, int start, int ceiling) {
    for (var i = ceiling - 1; i >= start; i--) {
      if (_endsASentence(text.codeUnitAt(i))) return i + 1;
    }
    for (var i = ceiling - 1; i >= start; i--) {
      // The space stays with the piece before it rather than opening the next
      // one, which keeps the pieces' concatenation exact either way and
      // leaves no utterance beginning on a space.
      if (_isSpace(text.codeUnitAt(i))) return i + 1;
    }
    // Neither, so the cut falls where the limit does — except that a high
    // surrogate there is the first half of one character, and splitting it
    // would hand each utterance half of a code point. One code unit earlier
    // is still inside the limit, and is only ever unsafe if the limit is 1.
    final onASurrogate = _isHighSurrogate(text.codeUnitAt(ceiling - 1));
    return onASurrogate && ceiling - 1 > start ? ceiling - 1 : ceiling;
  }

  /// Full stop, question and exclamation marks, Arabic's own question mark
  /// and full stop, and a line break — the places a reader's voice drops
  /// anyway, so a gap there passes for a pause rather than a fault.
  static bool _endsASentence(int codeUnit) => switch (codeUnit) {
    0x2E || 0x21 || 0x3F => true, // . ! ?
    0x061F || 0x06D4 => true, // ؟ ۔
    0x0A || 0x0D => true, // \n \r
    _ => false,
  };

  static bool _isSpace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0xA0;

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
}
