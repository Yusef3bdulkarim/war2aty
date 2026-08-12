import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/confidence_label.dart';
import '../../../../core/documents/document_analysis.dart';
import '../../../../core/documents/key_information.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/localization/app_strings.dart';

/// Assembles the text `TextToSpeechService.speak` reads for one [ReadingMode].
///
/// Everything it needs is already on [AnalysisResult] — the same result
/// already drawn on screen — so the text is built entirely on-device and
/// nothing about the document travels anywhere to produce it (privacy §7).
/// `AnalysisSummary.detailed` already reads as one, so `fullExplanation`
/// uses it untouched rather than re-narrating every section.
///
/// Synchronous and total: composing text out of an entity that already
/// exists cannot fail, so there is nothing to wrap in a `Result` (the same
/// reasoning `BuildAnalysisResult` documents for itself).
///
/// Takes a whole [AnalysisResult] — which always carries a `DocumentAnalysis`
/// — so it only applies to the result screen's "ready" state. The OCR-only
/// fallback (`AnalysisResultFailed`, unsupported documents) has no analysis
/// to wrap one in; it already holds the plain extracted text and speaks that
/// straight to `TextToSpeechService`, with no builder needed for it.
final class BuildReadingText {
  const BuildReadingText();

  String call({
    required AnalysisResult result,
    required ReadingMode mode,
    required AppStrings strings,
  }) => switch (mode) {
    ReadingMode.summaryOnly => result.analysis.summary.short.trim(),
    ReadingMode.fullExplanation => result.analysis.summary.detailed.trim(),
    ReadingMode.extractedText => result.extractedText.trim(),
    ReadingMode.summaryAndKeyInformation => _summaryAndKeyInformation(
      result.analysis,
      strings,
    ),
  };

  /// The quick summary, then one sentence per labelled fact.
  ///
  /// Reuses `resultKeyInformationTitle` as the spoken heading rather than
  /// inventing new copy, and the same caveats `ResultKeyInformationCard`
  /// shows beneath a value (§30.5) — an uncertain or inferred reading is
  /// never read aloud as plain fact any more than it is shown as one.
  String _summaryAndKeyInformation(
    DocumentAnalysis analysis,
    AppStrings strings,
  ) {
    final sentences = [
      analysis.summary.short.trim(),
      if (analysis.keyInformation.isNotEmpty) strings.resultKeyInformationTitle,
      for (final item in analysis.keyInformation)
        _keyInformationSentence(item, strings),
    ]..removeWhere((sentence) => sentence.isEmpty);

    return sentences.join('. ');
  }

  String _keyInformationSentence(KeyInformation item, AppStrings strings) {
    final caveats = [
      ?confidenceLabel(strings, item.confidence),
      if (item.source == InfoSource.inferred) strings.resultActionInferred,
    ];

    final sentence = '${item.label}: ${item.value}';
    return caveats.isEmpty ? sentence : '$sentence. ${caveats.join('. ')}';
  }
}
