/// A bundle of the session identifier and the processed image path, created
/// after the user confirms capture and the quality decision is resolved.
///
/// This is the handoff token from F03 (capture) to F04 (OCR + analysis).
/// Pure Dart, no Flutter import.
final class AnalysisSession {
  const AnalysisSession({required this.id, required this.imagePath});

  /// UUID v4 that scopes every artefact of this analysis run.
  final String id;

  /// Absolute path to the processed (rotated, quality-checked) image inside
  /// the session directory: `<cache>/analysis_sessions/{id}/processed.jpg`.
  final String imagePath;

  @override
  bool operator ==(Object other) =>
      other is AnalysisSession &&
      other.id == id &&
      other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(id, imagePath);

  @override
  String toString() => 'AnalysisSession($id, $imagePath)';
}
