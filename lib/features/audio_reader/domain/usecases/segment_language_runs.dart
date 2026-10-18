import '../entities/language_run.dart';

/// Splits a reading into the [LanguageRun]s it is made of (F30-T10).
///
/// The first half of the fix for RC-4: an Arabic paper with English words in
/// it was spoken as one utterance by one voice, and whichever script lost
/// got named character by character. F30-T11 speaks these runs as a queue,
/// each with a voice that can pronounce it.
///
/// Neutral characters — digits, spaces, punctuation — belong to no language
/// of their own, so a stretch of them is folded into a neighbouring run
/// rather than becoming a run of its own: splitting «المبلغ 500 جنيه» at
/// every digit would turn one utterance into three, each paying for the gap
/// between queue items (F30 locked decision 6). A neutral stretch between
/// two *different* languages binds to the run that **follows** it, because a
/// number binds to the word after it in both languages the app reads — «15
/// March» reads as English, «500 جنيه» as Arabic. A neutral tail at the end
/// of the reading has no following run, so it joins the last one.
///
/// Synchronous and total, like `BuildReadingText` — slicing a string that
/// already exists cannot fail, so there is nothing to wrap in a `Result`.
///
/// Guarantees, all of them asserted in tests because the queue work leans on
/// them:
///
/// * Concatenating every run reproduces the input exactly.
/// * No run is empty.
/// * No two neighbouring runs share a language.
final class SegmentLanguageRuns {
  const SegmentLanguageRuns();

  List<LanguageRun> call(String text) {
    if (text.isEmpty) return const [];

    final runs = <LanguageRun>[];
    // Where the run being built starts, and what language it is. The
    // language stays null until the first non-neutral character arrives — a
    // reading can open with a stretch of digits.
    var runStart = 0;
    ReadingLanguage? runLanguage;
    // Where the neutral stretch immediately before the current character
    // began, or -1 when the previous character was not neutral. It is the
    // boundary a language change cuts at, which is what binds a neutral
    // stretch to the run that follows it.
    var neutralStart = -1;

    for (var i = 0; i < text.length; i++) {
      final language = ReadingLanguage.ofCodeUnit(text.codeUnitAt(i));
      if (language == null) {
        if (neutralStart < 0) neutralStart = i;
        continue;
      }
      if (runLanguage == null) {
        // A neutral opening is this run's beginning, not a run of its own:
        // there is no earlier language for it to bind to.
        runLanguage = language;
      } else if (runLanguage != language) {
        final boundary = neutralStart < 0 ? i : neutralStart;
        runs.add(
          LanguageRun(
            text: text.substring(runStart, boundary),
            language: runLanguage,
          ),
        );
        runStart = boundary;
        runLanguage = language;
      }
      neutralStart = -1;
    }

    // Whatever is left: the last language run plus any neutral tail — or,
    // when the reading had no letters in it at all, the whole text.
    runs.add(
      LanguageRun(
        text: text.substring(runStart),
        language: runLanguage ?? _allNeutralLanguage,
      ),
    );
    return runs;
  }
}

/// The language to read a text with no letters in it at all — a bare date or
/// reference number, say — which is nobody's language in particular.
///
/// Arabic, the app's own language, and the same way `SelectVoiceForReading`
/// has always broken a tie.
const _allNeutralLanguage = ReadingLanguage.arabic;
