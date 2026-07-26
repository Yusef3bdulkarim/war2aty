/// The OCR text after normalization: digit unification, whitespace cleanup,
/// and currency symbol standardization.
///
/// Both the original and cleaned versions are kept so the UI can show the
/// cleaned text while the original is available for auditing.
/// Pure Dart, no Flutter import.
final class NormalizedOcrText {
  const NormalizedOcrText({
    required this.originalText,
    required this.cleanedText,
  });

  /// The raw OCR output, untouched.
  final String originalText;

  /// Normalized copy: Arabic-Indic digits → Western, excess whitespace
  /// collapsed, currency symbols unified.
  final String cleanedText;

  @override
  bool operator ==(Object other) =>
      other is NormalizedOcrText &&
      other.originalText == originalText &&
      other.cleanedText == cleanedText;

  @override
  int get hashCode => Object.hash(originalText, cleanedText);

  @override
  String toString() =>
      'NormalizedOcrText(original=${originalText.length}, '
      'cleaned=${cleanedText.length})';
}
