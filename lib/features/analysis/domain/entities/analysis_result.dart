import '../../../../core/documents/document_analysis.dart';
import '../../../../core/utils/list_equality.dart';
import 'analysis_section.dart';

/// One analysed paper, ready to be shown: the understanding itself, the text
/// it was derived from, and which blocks the screen has to draw.
///
/// Built by `BuildAnalysisResult`. [sections] is already ordered and already
/// filtered, so the screen renders it as a plain list and never decides for
/// itself what comes first or what to hide.
///
/// Pure Dart, no Flutter import.
final class AnalysisResult {
  const AnalysisResult({
    required this.analysis,
    required this.extractedText,
    required this.sections,
  });

  final DocumentAnalysis analysis;

  /// The normalized OCR text the analysis was built from.
  ///
  /// Travels with the result because the user can always go back to what was
  /// actually read off the paper (UX rule §5.12) — the app never asks them to
  /// take its reading on trust.
  final String extractedText;

  /// The blocks to draw, in display order (§4). Only sections with something
  /// to show are present.
  final List<AnalysisSection> sections;

  /// Whether [section] is part of this result.
  bool has(AnalysisSection section) => sections.contains(section);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisResult &&
          other.analysis == analysis &&
          other.extractedText == extractedText &&
          listEquals(other.sections, sections);

  @override
  int get hashCode =>
      Object.hash(analysis, extractedText, Object.hashAll(sections));

  // Neither the analysis nor the text is printed — both are document content
  // and entity toStrings reach logs and error reports (privacy §7).
  @override
  String toString() => 'AnalysisResult(${sections.length} sections)';
}
