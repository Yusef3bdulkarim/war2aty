import 'confidence_band.dart';

/// A money figure found on the document.
final class AnalysisAmount {
  const AnalysisAmount({
    required this.label,
    required this.value,
    required this.currency,
    required this.confidence,
    this.rawValue,
  });

  /// Arabic label, e.g. «إجمالي المبلغ».
  final String label;

  final double value;

  /// ISO-4217-ish code as the analysis reported it, e.g. `EGP`.
  final String currency;

  final ConfidenceBand confidence;

  /// The literal text this amount was matched from, or `null` when the value
  /// was inferred rather than read verbatim (API_CONTRACT §30 v2, F13-T17).
  final String? rawValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisAmount &&
          other.label == label &&
          other.value == value &&
          other.currency == currency &&
          other.confidence == confidence &&
          other.rawValue == rawValue;

  @override
  int get hashCode => Object.hash(label, value, currency, confidence, rawValue);

  // Amount and label both omitted — never log document figures, and the label
  // is AI-written text about this paper rather than a fixed name (privacy §7).
  @override
  String toString() => 'AnalysisAmount($currency, $confidence)';
}
