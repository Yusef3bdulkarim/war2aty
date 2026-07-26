/// A phone number found by rule-based extraction from normalized OCR text.
///
/// Pure Dart, no Flutter import.
final class PhoneCandidate {
  const PhoneCandidate({
    required this.rawText,
    required this.normalizedNumber,
    this.isAmbiguous = false,
  });

  /// The matched substring from the normalized text.
  final String rawText;

  /// Digits-only normalized form (e.g. "01012345678").
  final String normalizedNumber;

  /// True when the number was reassembled from fragmented OCR output.
  final bool isAmbiguous;

  @override
  bool operator ==(Object other) =>
      other is PhoneCandidate &&
      other.rawText == rawText &&
      other.normalizedNumber == normalizedNumber &&
      other.isAmbiguous == isAmbiguous;

  @override
  int get hashCode => Object.hash(rawText, normalizedNumber, isAmbiguous);

  @override
  String toString() =>
      'PhoneCandidate($rawText, normalized=$normalizedNumber, '
      'ambiguous=$isAmbiguous)';
}
