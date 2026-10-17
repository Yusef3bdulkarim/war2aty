/// One stretch of a reading that is spoken in a single language (F30-T10).
///
/// `SelectVoiceForReading` collapsed a whole reading to one dominant script
/// and `StartReading` spoke it as a single utterance, so an `ar-*` voice got
/// handed the Latin words inside an Arabic paper. An Arabic voice has no
/// Latin grapheme rules, so it names those characters one at a time — the
/// owner's "English inside an Arabic paper is read letter-by-letter" (F30
/// RC-4). Splitting the text into runs first is what lets each run be spoken
/// by a voice that can actually pronounce it (F30 locked decision 2).
///
/// [text] is a verbatim slice of the reading: concatenating every run of a
/// segmentation reproduces the original text exactly, including its spaces
/// and punctuation. Progress across the queue (F30-T13) counts on that — a
/// run's offset into the reading is the sum of the lengths before it.
final class LanguageRun {
  const LanguageRun({required this.text, required this.language})
    : assert(text != '', 'an empty run has nothing to speak');

  /// The slice of the reading this run covers, never empty — an empty
  /// utterance behaves differently on every engine (F30 "Secondary"), so one
  /// is not allowed to exist in the first place rather than be filtered out
  /// further down the queue.
  final String text;

  /// The language this run is to be spoken in.
  final ReadingLanguage language;

  @override
  bool operator ==(Object other) =>
      other is LanguageRun && other.text == text && other.language == language;

  @override
  int get hashCode => Object.hash(text, language);

  @override
  String toString() => 'LanguageRun($language, "$text")';
}

/// A language a reading can be spoken in — the two the app has copy for, and
/// the two scripts an Egyptian paper is written in (project context:
/// "المستند نفسه قد يكون عربي/إنجليزي/مختلط").
///
/// [code] is the prefix a voice's locale has to start with to read the run,
/// matching what `SelectVoiceForReading` matches on.
enum ReadingLanguage {
  arabic('ar'),
  english('en');

  const ReadingLanguage(this.code);

  final String code;

  /// The language a single UTF-16 code unit is written in, or `null` when it
  /// is **neutral** — a digit, a space, a punctuation mark, an emoji, half of
  /// a surrogate pair: anything that belongs to no language of its own and so
  /// reads the same in either voice.
  ///
  /// Latin script maps to [english] because English is the only
  /// Latin-script language the app reads. Arabic covers the Arabic block
  /// (`U+0600`-`U+06FF`) and the Arabic Supplement (`U+0750`-`U+077F`) — the
  /// same two blocks `SelectVoiceForReading` has counted since F10-T07, which
  /// now counts them through here so "what script is this character" has one
  /// definition rather than two that can drift apart.
  ///
  /// Note that the Arabic block carries Arabic-Indic digits (`٠`-`٩`) and
  /// Arabic punctuation (`،`, `؟`) as well as letters, so those count as
  /// Arabic rather than neutral. That is the behaviour we want: a `٥` is only
  /// ever read in Arabic.
  static ReadingLanguage? ofCodeUnit(int codeUnit) {
    if (codeUnit >= 0x0600 && codeUnit <= 0x06FF) return arabic;
    if (codeUnit >= 0x0750 && codeUnit <= 0x077F) return arabic;
    if (codeUnit >= 0x41 && codeUnit <= 0x5A) return english;
    if (codeUnit >= 0x61 && codeUnit <= 0x7A) return english;
    return null;
  }
}
