import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/analysis_section.dart';
import '../../../../core/documents/confidence_label.dart';
import '../../../../core/documents/document_analysis.dart';
import '../../../../core/documents/key_information.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/documents/required_action.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/money/document_amount_label.dart';
import '../../../../core/time/document_date_label.dart';
import 'normalize_spoken_numbers.dart';

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
  }) {
    final raw = switch (mode) {
      ReadingMode.summaryOnly => result.analysis.summary.short,
      ReadingMode.fullExplanation => result.analysis.summary.detailed,
      ReadingMode.extractedText => result.extractedText,
      ReadingMode.summaryAndKeyInformation => _summaryAndKeyInformation(
        result.analysis,
        strings,
      ),
      ReadingMode.readAll => _readAll(result, strings),
    };
    // The one choke point every reading mode passes through, so a phone
    // number, date, or amount is spoken the same way no matter which mode
    // read it out.
    return normalizeSpokenNumbers(raw).trim();
  }

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

  /// Every section on the result screen, narrated in [AnalysisSection] order.
  ///
  /// Only sections present in [result.sections] are included — the same filter
  /// `BuildAnalysisResult` already applied, so a missing section is never read
  /// aloud. Each section opens with its heading (reusing the same
  /// `AppStrings` keys the cards show) and then its content, separated by
  /// full stops so the TTS engine pauses naturally between them.
  String _readAll(AnalysisResult result, AppStrings strings) {
    final analysis = result.analysis;
    final sentences = <String>[];

    for (final section in result.sections) {
      switch (section) {
        case AnalysisSection.header:
          sentences.add(analysis.title);

        case AnalysisSection.summary:
          sentences.add(analysis.summary.short.trim());

        case AnalysisSection.actionRequired:
          sentences.add(strings.resultActionRequiredTitle);
          for (final action in analysis.actions) {
            final basis = action.basis == ActionBasis.inferred
                ? '. ${strings.resultActionInferred}'
                : '';
            sentences.add('${action.description.trim()}$basis');
          }

        case AnalysisSection.warnings:
          sentences.add(strings.resultWarningsTitle);
          for (final warning in analysis.warnings) {
            sentences.add(warning.text.trim());
          }

        case AnalysisSection.keyInformation:
          sentences.add(strings.resultKeyInformationTitle);
          for (final item in analysis.keyInformation) {
            sentences.add(_keyInformationSentence(item, strings));
          }

        case AnalysisSection.amounts:
          sentences.add(strings.resultAmountsTitle);
          for (final amount in analysis.amounts) {
            final formatted = formatDocumentAmount(
              strings,
              amount.value,
              amount.currency,
            );
            final caveat = confidenceLabel(strings, amount.confidence);
            final suffix = caveat != null ? '. $caveat' : '';
            sentences.add('${amount.label}: $formatted$suffix');
          }

        case AnalysisSection.dates:
          sentences.add(strings.resultDatesTitle);
          for (final date in analysis.dates) {
            final formatted = formatDocumentDate(strings, date.date);
            final time = date.time;
            final timeText = time == null
                ? strings.resultDateNoTime
                : formatWallClockTime(strings, time.hour, time.minute);
            final caveat = confidenceLabel(strings, date.confidence);
            final suffix = caveat != null ? '. $caveat' : '';
            sentences.add('${date.label}: $formatted, $timeText$suffix');
          }

        case AnalysisSection.requiredDocuments:
          sentences.add(strings.resultRequiredDocumentsTitle);
          for (final doc in analysis.requiredDocuments) {
            sentences.add(doc.trim());
          }

        case AnalysisSection.instructions:
          sentences.add(strings.resultInstructionsTitle);
          for (final (index, step) in analysis.instructions.indexed) {
            sentences.add('${index + 1}. ${step.trim()}');
          }

        case AnalysisSection.detailedExplanation:
          sentences.add(analysis.summary.detailed.trim());

        case AnalysisSection.extractedText:
          sentences.add(strings.resultShowExtractedText);
          sentences.add(result.extractedText.trim());
      }
    }

    sentences.removeWhere((s) => s.isEmpty);
    return sentences.join('. ');
  }
}
