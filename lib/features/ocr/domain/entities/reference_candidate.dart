/// A reference/account/invoice number found by rule-based extraction.
///
/// Always flagged [isAmbiguous] because reference number formats vary
/// wildly and we cannot validate them. Pure Dart, no Flutter import.
final class ReferenceCandidate {
  const ReferenceCandidate({
    required this.rawText,
    required this.value,
    this.isAmbiguous = true,
  });

  /// The matched substring from the normalized text (keyword + number).
  final String rawText;

  /// The extracted alphanumeric reference value.
  final String value;

  /// Always true — reference formats cannot be validated locally.
  final bool isAmbiguous;

  @override
  bool operator ==(Object other) =>
      other is ReferenceCandidate &&
      other.rawText == rawText &&
      other.value == value &&
      other.isAmbiguous == isAmbiguous;

  @override
  int get hashCode => Object.hash(rawText, value, isAmbiguous);

  @override
  String toString() =>
      'ReferenceCandidate($rawText, value=$value, '
      'ambiguous=$isAmbiguous)';
}
