import 'dart:math' as math;

import '../entities/pcm_format.dart';
import '../entities/spoken_card_span.dart';
import '../entities/transcript_audio_anchor.dart';
import '../entities/voice_segment.dart';
import 'normalise_arabic_for_diff.dart';

/// Works out when each segment of the page is spoken, from the read's own
/// transcription and the frames that carried transcript and audio together
/// (F37-T07).
///
/// F40 uses the result to highlight and scroll to the card being read, and to
/// jump to one the user taps. That is a convenience on top of the read, never a
/// condition of it, so **alignment never fails**: every segment always gets a
/// span, and `SpokenCardSpan.exact` is what tells the caller which ones were
/// actually measured. A date printed «20 نوفمبر» and spoken «عشرين نوفمبر» is
/// the likeliest segment to go unmatched, and the most important one not to
/// mis-highlight while claiming precision.
///
/// The three ideas, in the order they apply:
///
/// 1. **Anchors come only from frames carrying both.** Audio runs ahead of its
///    transcription, so a byte count taken when a lone transcript delta lands
///    measures arrival, not speech. See [TranscriptAudioAnchor].
/// 2. **Words are matched forward-only.** The page's words and the
///    transcription's are folded by [NormaliseArabicForDiff] and matched by the
///    same longest-common-subsequence walk the verbatim check uses, so a
///    re-spelled or dropped word shifts nothing after it.
/// 3. **Everything else is interpolated by character share.** A segment that
///    could not be matched is placed between its matched neighbours in
///    proportion to its characters; with no matched neighbours at all that
///    reduces exactly to `charsBefore / totalChars × duration`.
///
/// The spans are returned as a **partition** of the read: each one ends where
/// the next begins, and the last ends with the audio. F40 then always has
/// exactly one answer to "which card is being read now", and the pause between
/// two cards belongs to the card before it rather than to nothing. A
/// zero-length span is possible where two segments matched the same word, and
/// `SpokenCardSpan.contains` is false throughout it, which is the honest
/// outcome.
final class AlignSegmentsToAudio {
  const AlignSegmentsToAudio(this._normalise);

  final NormaliseArabicForDiff _normalise;

  /// How many of a segment's words must appear in the transcription before its
  /// first match is trusted as a boundary.
  ///
  /// One word is not enough: «في» or «من» matching by coincidence inside an
  /// otherwise unrecognised card would anchor that card to the wrong second,
  /// and mark it `exact` while doing so. Two makes an accidental anchor far
  /// less likely. A segment with only one word can never offer two, so the
  /// requirement is capped at the segment's own length.
  static const int minMatchedWords = 2;

  List<SpokenCardSpan> call({
    required List<VoiceSegment> segments,
    required String transcript,
    required List<TranscriptAudioAnchor> anchors,
    required int totalAudioBytes,
    required PcmFormat format,
  }) {
    if (segments.isEmpty) return const [];

    final totalMicros = format
        .durationOfBytes(math.max(0, totalAudioBytes))
        .inMicroseconds;
    final charsBefore = _charsBefore(segments);
    final totalChars = charsBefore.last;

    // No frame tied the two together, so there is no timeline to match against
    // — only the page's own shape. The transcription may be complete and
    // perfect and it still cannot say *when* anything was said.
    final anchorPoints = _anchorPoints(anchors, transcript, totalAudioBytes);
    if (anchorPoints == null) {
      return _spansFrom(
        segments: segments,
        starts: _proportional(charsBefore, totalChars, totalMicros),
        exact: List<bool>.filled(segments.length, false),
        totalMicros: totalMicros,
      );
    }

    final startMicros = List<int>.filled(segments.length, 0);
    final exact = List<bool>.filled(segments.length, false);
    final matchedWord = _firstMatchedWordOf(segments, anchorPoints.words);

    for (var i = 0; i < segments.length; i++) {
      final word = matchedWord[i];
      if (word == null) continue;
      exact[i] = true;
      startMicros[i] = format
          .durationOfBytes(
            _interpolateAt(anchorPoints.wordCounts, anchorPoints.bytes, word),
          )
          .inMicroseconds;
    }

    _placeUnmatched(
      charsBefore: charsBefore,
      totalChars: totalChars,
      totalMicros: totalMicros,
      startMicros: startMicros,
      exact: exact,
    );

    return _spansFrom(
      segments: segments,
      starts: startMicros,
      exact: exact,
      totalMicros: totalMicros,
    );
  }

  /// Cumulative character offsets, plus the page total as a final entry.
  ///
  /// Counted from the segments' own text, deliberately **not** from the turn
  /// text T06 builds: the blank line and full stop it inserts between segments
  /// are separators, not speech, and counting them would make this use case
  /// depend on how the turn happens to be punctuated. The short pause each one
  /// produces is absorbed into the span of the segment before it.
  ///
  /// A page whose segments are all empty would divide by zero, so every segment
  /// then weighs one and the spans come out evenly spaced.
  List<int> _charsBefore(List<VoiceSegment> segments) {
    final allEmpty = segments.every((segment) => segment.text.isEmpty);
    final offsets = <int>[0];
    for (final segment in segments) {
      offsets.add(offsets.last + (allEmpty ? 1 : segment.text.length));
    }
    return offsets;
  }

  List<int> _proportional(List<int> charsBefore, int totalChars, int micros) {
    return List<int>.generate(
      charsBefore.length - 1,
      (i) => totalChars == 0 ? 0 : charsBefore[i] * micros ~/ totalChars,
    );
  }

  /// The transcription's words, and the (word count → byte offset) points the
  /// anchors provide. `null` when there is nothing to align against.
  _AnchorPoints? _anchorPoints(
    List<TranscriptAudioAnchor> anchors,
    String transcript,
    int totalAudioBytes,
  ) {
    if (anchors.isEmpty || totalAudioBytes <= 0) return null;
    final words = _normalise.wordsOf(transcript);
    if (words.isEmpty) return null;

    // The read starts at the start of the audio: a real observation, and the
    // left-hand end of every interpolation.
    final wordCounts = <int>[0];
    final bytes = <int>[0];
    for (final anchor in anchors) {
      // The newest delta can land mid-word, so the last word an anchor appears
      // to carry may be a fragment. Dropping it costs at most half a word of
      // precision and errs towards placing a card early rather than late.
      final heard = _normalise.wordsOf(anchor.transcriptSoFar).length;
      final counted = math.max(0, heard - 1);
      final offset = anchor.audioBytesSoFar;
      // An anchor that advances neither count carries nothing, and one that
      // claims more words than the whole transcription has, or more bytes than
      // were played, is not describing this read.
      if (counted <= wordCounts.last || counted >= words.length) continue;
      if (offset <= bytes.last || offset > totalAudioBytes) continue;
      wordCounts.add(counted);
      bytes.add(offset);
    }

    // The read ends with the audio, which closes the last interval.
    if (words.length > wordCounts.last && totalAudioBytes > bytes.last) {
      wordCounts.add(words.length);
      bytes.add(totalAudioBytes);
    }
    if (wordCounts.length < 2) return null;

    return _AnchorPoints(words: words, wordCounts: wordCounts, bytes: bytes);
  }

  /// For each segment, the transcription word index its reading begins at, or
  /// `null` when it was not recognised confidently enough to say.
  List<int?> _firstMatchedWordOf(
    List<VoiceSegment> segments,
    List<String> transcriptWords,
  ) {
    final pageWords = <String>[];
    final owner = <int>[];
    for (var i = 0; i < segments.length; i++) {
      for (final word in _normalise.wordsOf(segments[i].text)) {
        pageWords.add(word);
        owner.add(i);
      }
    }
    final segmentWords = List<int>.filled(segments.length, 0);
    for (final segment in owner) {
      segmentWords[segment]++;
    }

    final firstWord = List<int?>.filled(segments.length, null);
    final matchedWords = List<int>.filled(segments.length, 0);
    for (final match in _forwardMatches(pageWords, transcriptWords)) {
      final segment = owner[match.pageIndex];
      firstWord[segment] ??= match.transcriptIndex;
      matchedWords[segment]++;
    }

    for (var i = 0; i < segments.length; i++) {
      final needed = math.min(minMatchedWords, segmentWords[i]);
      if (needed == 0 || matchedWords[i] < needed) firstWord[i] = null;
    }
    return firstWord;
  }

  /// Word-level longest common subsequence, walked forward only, reporting
  /// *where* the words line up rather than which ones differ.
  ///
  /// The table and its tie-break are `VerifyVerbatimRead.compareWords`'s, and
  /// the two are deliberately separate rather than one shared helper: that one
  /// answers whether the read may be played at all and returns a pair of word
  /// lists, this one answers where to scroll and returns a pair of indices. A
  /// page is a few dozen words, so the quadratic table is free.
  List<_WordMatch> _forwardMatches(List<String> page, List<String> heard) {
    final rows = page.length;
    final cols = heard.length;
    if (rows == 0 || cols == 0) return const [];

    final lcs = List.generate(
      rows + 1,
      (_) => List<int>.filled(cols + 1, 0),
      growable: false,
    );
    for (var i = rows - 1; i >= 0; i--) {
      for (var j = cols - 1; j >= 0; j--) {
        lcs[i][j] = page[i] == heard[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }

    final matches = <_WordMatch>[];
    var i = 0;
    var j = 0;
    while (i < rows && j < cols) {
      if (page[i] == heard[j]) {
        matches.add(_WordMatch(pageIndex: i++, transcriptIndex: j++));
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return matches;
  }

  /// Places the segments that could not be matched, in proportion to their
  /// characters, between the ones that could.
  ///
  /// An unmatched card sitting between two measured ones is bounded by them,
  /// which is a far better guess than its share of the whole page. With nothing
  /// matched on either side the known points are only the start and the end of
  /// the audio, and this is `charsBefore / totalChars × duration` exactly.
  void _placeUnmatched({
    required List<int> charsBefore,
    required int totalChars,
    required int totalMicros,
    required List<int> startMicros,
    required List<bool> exact,
  }) {
    final knownChars = <int>[0];
    final knownMicros = <int>[0];
    for (var i = 0; i < startMicros.length; i++) {
      if (!exact[i]) continue;
      if (charsBefore[i] <= knownChars.last) continue;
      // Forward-only matching keeps these in order; the clamp guards the
      // arithmetic rather than distrusting the matcher.
      knownChars.add(charsBefore[i]);
      knownMicros.add(
        math.min(math.max(startMicros[i], knownMicros.last), totalMicros),
      );
    }
    if (totalChars > knownChars.last) {
      knownChars.add(totalChars);
      knownMicros.add(math.max(knownMicros.last, totalMicros));
    }

    for (var i = 0; i < startMicros.length; i++) {
      if (exact[i]) continue;
      startMicros[i] = _interpolateAt(knownChars, knownMicros, charsBefore[i]);
    }
  }

  /// Linear interpolation of [ys] at [x] over the non-decreasing [xs].
  int _interpolateAt(List<int> xs, List<int> ys, int x) {
    if (x <= xs.first) return ys.first;
    if (x >= xs.last) return ys.last;
    var hi = 1;
    while (hi < xs.length - 1 && xs[hi] < x) {
      hi++;
    }
    final lo = hi - 1;
    final run = xs[hi] - xs[lo];
    if (run <= 0) return ys[hi];
    return ys[lo] + (x - xs[lo]) * (ys[hi] - ys[lo]) ~/ run;
  }

  /// Turns per-segment starts into a partition of the read.
  ///
  /// The first segment starts with the audio by construction, each span ends
  /// where the next begins, and the last ends with the audio — so a position
  /// anywhere in the read belongs to exactly one segment. The monotonic clamp
  /// is a guard, not an expectation.
  List<SpokenCardSpan> _spansFrom({
    required List<VoiceSegment> segments,
    required List<int> starts,
    required List<bool> exact,
    required int totalMicros,
  }) {
    final ordered = List<int>.filled(segments.length, 0);
    var previous = 0;
    for (var i = 0; i < segments.length; i++) {
      previous = i == 0
          ? 0
          : math.min(math.max(starts[i], previous), totalMicros);
      ordered[i] = previous;
    }

    return List<SpokenCardSpan>.generate(segments.length, (i) {
      final end = i == segments.length - 1 ? totalMicros : ordered[i + 1];
      return SpokenCardSpan(
        segmentId: segments[i].id,
        start: Duration(microseconds: ordered[i]),
        end: Duration(microseconds: math.max(ordered[i], end)),
        exact: exact[i],
      );
    });
  }
}

final class _AnchorPoints {
  const _AnchorPoints({
    required this.words,
    required this.wordCounts,
    required this.bytes,
  });

  /// The whole read as folded words.
  final List<String> words;

  /// Strictly increasing word counts, and the byte offset each was heard by.
  final List<int> wordCounts;
  final List<int> bytes;
}

final class _WordMatch {
  const _WordMatch({required this.pageIndex, required this.transcriptIndex});

  final int pageIndex;
  final int transcriptIndex;
}
