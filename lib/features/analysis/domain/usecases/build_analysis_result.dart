import '../entities/analysis_result.dart';
import '../entities/analysis_section.dart';
import '../entities/document_analysis.dart';

/// Turns an understood document into the ordered screen it becomes.
///
/// Two decisions live here rather than in the widgets: **which** sections this
/// particular paper has anything to say in, and **in what order** they appear
/// (§4). Keeping them in the domain means the order is covered by a plain unit
/// test instead of a widget test, and a section can't quietly reorder itself
/// by being moved in a build method.
///
/// Synchronous and total — it reads an entity that already exists, so there is
/// nothing to fail and no `Result` to unwrap.
final class BuildAnalysisResult {
  const BuildAnalysisResult();

  /// [extractedText] is the normalized OCR text this analysis came from.
  AnalysisResult call({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) {
    return AnalysisResult(
      analysis: analysis,
      extractedText: extractedText,
      // Filtering the enum keeps §4's order structural: there is no second
      // list to keep in step with it.
      sections: AnalysisSection.values
          .where((section) => _hasContent(section, analysis, extractedText))
          .toList(growable: false),
    );
  }

  /// Whether [section] has anything to draw for this paper.
  ///
  /// An empty section is dropped rather than drawn empty: a titled card with
  /// nothing under it reads as something that failed to load.
  bool _hasContent(
    AnalysisSection section,
    DocumentAnalysis analysis,
    String extractedText,
  ) => switch (section) {
    // Always: the type and title are how the user recognises their own paper,
    // and they are present even in a partial result.
    AnalysisSection.header => true,
    AnalysisSection.summary => analysis.summary.short.trim().isNotEmpty,
    AnalysisSection.actionRequired => analysis.actions.isNotEmpty,
    AnalysisSection.warnings => analysis.warnings.isNotEmpty,
    AnalysisSection.keyInformation => analysis.keyInformation.isNotEmpty,
    AnalysisSection.amounts => analysis.amounts.isNotEmpty,
    AnalysisSection.dates => analysis.dates.isNotEmpty,
    AnalysisSection.requiredDocuments => analysis.requiredDocuments.isNotEmpty,
    AnalysisSection.instructions => analysis.instructions.isNotEmpty,
    AnalysisSection.detailedExplanation =>
      analysis.summary.detailed.trim().isNotEmpty,
    // Present whenever there is text at all — including on an unsupported
    // document, where it is the only thing left to show (UX rule §5.12).
    AnalysisSection.extractedText => extractedText.trim().isNotEmpty,
  };
}
