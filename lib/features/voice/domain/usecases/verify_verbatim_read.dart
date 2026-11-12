import 'normalise_arabic_for_diff.dart';

/// How close a reading came to the page it was given (F37-T05).
///
/// The three bands are the spike's own, reused unchanged so that a verdict in
/// production means what the verdict on the owner's machine meant.
enum VerbatimVerdict {
  /// At or under 5 % — the band all three spike reads landed in, at 0.0 %.
  verbatim,

  /// Over 5 % and at or under 15 %. Transcription noise and a politeness token
  /// live here, and so does the beginning of real trouble; the dropped and
  /// added words are what tell them apart.
  nearVerbatim,

  /// Over 15 % — the voice is paraphrasing or talking rather than reading.
  notVerbatim,
}

/// A word-level comparison of what was read against what should have been.
final class VerbatimComparison {
  VerbatimComparison({
    required this.wordErrorRate,
    required List<String> dropped,
    required List<String> added,
  }) : dropped = List.unmodifiable(dropped),
       added = List.unmodifiable(added);

  final double wordErrorRate;

  /// Words of the page that were not spoken.
  ///
  /// Document content: countable, never loggable (CLAUDE.md §7).
  final List<String> dropped;

  /// Words that were spoken but are not on the page.
  final List<String> added;

  VerbatimVerdict get verdict {
    if (wordErrorRate <= VerifyVerbatimRead.maxVerbatimWordErrorRate) {
      return VerbatimVerdict.verbatim;
    }
    if (wordErrorRate <= VerifyVerbatimRead.maxNearVerbatimWordErrorRate) {
      return VerbatimVerdict.nearVerbatim;
    }
    return VerbatimVerdict.notVerbatim;
  }

  bool get isAcceptable => verdict != VerbatimVerdict.notVerbatim;

  /// Deliberately omits the words themselves.
  @override
  String toString() =>
      'VerbatimComparison(${(wordErrorRate * 100).toStringAsFixed(1)}%, '
      '${dropped.length} dropped, ${added.length} added, $verdict)';
}

/// Checks that the voice read the page as written (F37-T05).
///
/// The risk this guards is not a bad connection but a *reworded* paper: the
/// reading voice is a chat model being used as a reader, and a user who cannot
/// read has no way to notice that the date they were told is not the date on
/// the page. The check costs nothing extra because the service transcribes its
/// own speech, so no second speech-to-text is involved.
///
/// Reports only. Whether to retry, to fall back, or to keep audio that failed
/// late is the reading use case's decision.
final class VerifyVerbatimRead {
  const VerifyVerbatimRead(this._normalise);

  final NormaliseArabicForDiff _normalise;

  /// The spike's "verbatim" band.
  static const double maxVerbatimWordErrorRate = 0.05;

  /// The spike's "near-verbatim" ceiling; above it the read is paraphrasing.
  static const double maxNearVerbatimWordErrorRate = 0.15;

  /// How many words must have been heard before an early verdict is allowed.
  ///
  /// Judging the first handful of words would fail honest reads constantly: a
  /// single added «أهلاً» is 50 % of two words and 5 % of forty. Twenty words
  /// is roughly two seconds of speech, which still aborts a bad read long
  /// before the user has sat through a whole wrong paper.
  static const int minWordsBeforeEarlyJudgement = 20;

  /// The final verdict, over the whole page.
  VerbatimComparison call({required String source, required String heard}) =>
      compareWords(_normalise.wordsOf(source), _normalise.wordsOf(heard));

  /// A verdict on a read that is still arriving, or `null` while it is too
  /// early to judge.
  ///
  /// Exists so a paraphrasing read is abandoned at the third second rather
  /// than the fortieth. Compares what has been heard against the *beginning*
  /// of the page, since that is all that should have been spoken yet.
  ///
  /// Callers should act only on [VerbatimVerdict.notVerbatim] here: the
  /// narrower 5 % band is for the complete read, and applying it to a fragment
  /// would abandon reads that go on to be perfect.
  VerbatimComparison? checkPrefix({
    required String source,
    required String heard,
  }) {
    final heardWords = _normalise.wordsOf(heard);
    if (heardWords.length < minWordsBeforeEarlyJudgement) return null;

    // The newest delta may have landed mid-word, which would otherwise show up
    // as one dropped plus one added word for no real reason.
    final settled = heardWords.sublist(0, heardWords.length - 1);
    final sourceWords = _normalise.wordsOf(source);

    if (settled.length >= sourceWords.length) {
      return compareWords(sourceWords, settled);
    }
    return compareWords(sourceWords.sublist(0, settled.length), settled);
  }

  /// Word-level longest-common-subsequence diff.
  ///
  /// A page is a few dozen words, so the quadratic table is free. Ported from
  /// `diffWords` in `supabase/tools/live-spike.ts` without changes, including
  /// its tie-break and its treatment of an empty page.
  VerbatimComparison compareWords(List<String> source, List<String> heard) {
    final rows = source.length;
    final cols = heard.length;
    final lcs = List.generate(
      rows + 1,
      (_) => List<int>.filled(cols + 1, 0),
      growable: false,
    );
    for (var i = rows - 1; i >= 0; i--) {
      for (var j = cols - 1; j >= 0; j--) {
        lcs[i][j] = source[i] == heard[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }

    final dropped = <String>[];
    final added = <String>[];
    var i = 0;
    var j = 0;
    while (i < rows && j < cols) {
      if (source[i] == heard[j]) {
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        dropped.add(source[i++]);
      } else {
        added.add(heard[j++]);
      }
    }
    while (i < rows) {
      dropped.add(source[i++]);
    }
    while (j < cols) {
      added.add(heard[j++]);
    }

    // An empty page counts as entirely unread rather than perfectly read: a
    // comparison with nothing to compare against must never report success.
    final wordErrorRate = rows == 0
        ? 1.0
        : (dropped.length + added.length) / rows;

    return VerbatimComparison(
      wordErrorRate: wordErrorRate,
      dropped: dropped,
      added: added,
    );
  }
}
