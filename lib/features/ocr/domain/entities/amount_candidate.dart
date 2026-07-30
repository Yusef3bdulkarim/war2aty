/// A monetary amount found by rule-based extraction from normalized OCR text.
///
/// Pure Dart, no Flutter import.
final class AmountCandidate {
  const AmountCandidate({
    required this.rawText,
    this.value,
    this.currency,
    this.isAmbiguous = false,
  });

  /// The matched substring from the normalized text.
  final String rawText;

  /// Parsed numeric value, or `null` when parsing failed.
  final double? value;

  /// Detected currency code (e.g. "EGP", "USD") or `null` when none found.
  final String? currency;

  /// True when the amount was inferred from keyword proximity rather than
  /// an explicit currency marker.
  final bool isAmbiguous;

  @override
  bool operator ==(Object other) =>
      other is AmountCandidate &&
      other.rawText == rawText &&
      other.value == value &&
      other.currency == currency &&
      other.isAmbiguous == isAmbiguous;

  @override
  int get hashCode => Object.hash(rawText, value, currency, isAmbiguous);

  @override
  String toString() =>
      'AmountCandidate($rawText, value=$value, '
      'currency=$currency, ambiguous=$isAmbiguous)';
}
