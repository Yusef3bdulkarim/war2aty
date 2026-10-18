import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/localization/app_strings.dart';
import 'build_reading_text.dart';

/// The modes the options sheet may offer for one paper, in display order
/// (F30-T19).
///
/// The sheet used to offer all four unconditionally, while
/// `BuildAnalysisResult` only puts the summary section on screen when
/// `summary.short` has something in it. So a paper whose summary came back
/// blank still offered «التلخيص فقط», and choosing it sent the empty string
/// to the engine — whose behaviour for an empty utterance is its own
/// business, and nobody's idea of a reading (F30 "Secondary").
///
/// A mode has content when [BuildReadingText] produces something for it, and
/// that is the only definition used: asking the builder itself is what keeps
/// "this mode has something to read" and "this is what it reads" from
/// becoming two answers that can drift apart. The queue refuses an empty
/// utterance as well, which is the floor under this rather than a substitute
/// for it — a mode that cannot be read should not be offered in the first
/// place, not offered and then refused.
///
/// [ReadingMode.extractedText] is not among the candidates: it has no
/// analysis to summarise and is only reached by reading a fallback screen's
/// text straight away.
///
/// Synchronous and total, like [BuildReadingText] underneath it.
final class OfferableReadingModes {
  const OfferableReadingModes(this._buildReadingText);

  final BuildReadingText _buildReadingText;

  /// Which of [candidates] have something to say about [result].
  ///
  /// Empty only when the paper has nothing readable at all — which, since
  /// every section the screen draws is also read by [ReadingMode.readAll],
  /// means the screen behind the sheet is blank too. The caller opens no
  /// sheet then: there is nothing in it to pick.
  List<ReadingMode> call({
    required AnalysisResult result,
    required AppStrings strings,
  }) => [
    for (final mode in candidates)
      if (_buildReadingText(
        result: result,
        mode: mode,
        strings: strings,
      ).isNotEmpty)
        mode,
  ];

  /// Every mode the sheet can offer, in the order it lists them.
  static const candidates = [
    ReadingMode.summaryOnly,
    ReadingMode.summaryAndKeyInformation,
    ReadingMode.fullExplanation,
    ReadingMode.readAll,
  ];
}
