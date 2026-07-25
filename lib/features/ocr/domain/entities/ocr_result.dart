/// Raw output from the OCR engine — plain text and detected languages.
///
/// This is the unprocessed OCR output before normalization or candidate
/// extraction. Pure Dart, no Flutter import.
final class OcrResult {
  const OcrResult({
    required this.originalText,
    this.detectedLanguages = const [],
  });

  /// The full recognized text, concatenated from all text blocks in reading
  /// order. No normalization applied — Arabic-Indic digits, extra whitespace,
  /// and OCR artifacts are preserved as-is.
  final String originalText;

  /// BCP-47 language tags detected by the engine (e.g. `['ar', 'en']`).
  /// Empty when the engine cannot determine the language.
  final List<String> detectedLanguages;

  @override
  bool operator ==(Object other) =>
      other is OcrResult &&
      other.originalText == originalText &&
      _listEquals(other.detectedLanguages, detectedLanguages);

  @override
  int get hashCode =>
      Object.hash(originalText, Object.hashAll(detectedLanguages));

  @override
  String toString() =>
      'OcrResult(${originalText.length} chars, langs=$detectedLanguages)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
