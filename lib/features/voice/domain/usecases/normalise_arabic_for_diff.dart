/// Folds away everything a transcriber may legitimately render differently,
/// so that two spellings of the same Arabic sentence compare equal (F37-T05).
///
/// A port of `normalise` / `words` in `supabase/tools/live-spike.ts`, kept
/// deliberately identical: the Deno tool decided whether F37 could be built at
/// all, and the app now makes the same judgement on every read in production.
/// If the two folders drift, the gate that passed on the owner's machine stops
/// meaning anything about what users hear. `live-spike-diff.test.ts`'s cases
/// are ported alongside it for exactly that reason.
///
/// This is **lossy and not invertible** — which is why it can decide *whether*
/// a read was verbatim but cannot be used to locate a word in the audio.
/// Segment alignment therefore anchors on frames rather than on folded words.
final class NormaliseArabicForDiff {
  const NormaliseArabicForDiff();

  /// Diacritics (U+064B–U+0652), the superscript alef (U+0670) and tatweel
  /// (U+0640) — all of which a transcriber may simply omit.
  static final RegExp _diacritics = RegExp('[ً-ْٰـ]');

  static final RegExp _alefFamily = RegExp('[آأإا]');
  static final RegExp _yaFamily = RegExp('[ىي]');
  static final RegExp _taMarbuta = RegExp('ة');

  /// Arabic-Indic (U+0660–U+0669) and Extended Arabic-Indic (U+06F0–U+06F9).
  ///
  /// Both exist because a page may be printed with either and the voice may
  /// read back ASCII. Folding them is what lets «٢٠ نوفمبر» and «20 نوفمبر»
  /// compare equal — the single most important case here, since a date is what
  /// a user acts on.
  static final RegExp _arabicIndicDigits = RegExp('[٠-٩]');
  static final RegExp _extendedArabicIndicDigits = RegExp('[۰-۹]');

  /// Anything that is neither a letter, a number nor whitespace. Punctuation
  /// is a transcription choice, not content.
  static final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static final RegExp _whitespaceRuns = RegExp(r'\s+');

  String call(String text) {
    return text
        .replaceAll(_diacritics, '')
        .replaceAll(_alefFamily, 'ا')
        .replaceAll(_yaFamily, 'ي')
        .replaceAll(_taMarbuta, 'ه')
        .replaceAllMapped(
          _arabicIndicDigits,
          (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}',
        )
        .replaceAllMapped(
          _extendedArabicIndicDigits,
          (m) => '${m.group(0)!.codeUnitAt(0) - 0x06F0}',
        )
        .replaceAll(_nonWord, ' ')
        .replaceAll(_whitespaceRuns, ' ')
        .trim();
  }

  /// The folded text as words.
  ///
  /// Empty text yields no words rather than one empty word, so that a page
  /// of pure punctuation cannot be counted as having been read.
  List<String> wordsOf(String text) {
    final folded = call(text);
    return folded.isEmpty ? const [] : folded.split(' ');
  }
}
