import 'confidence_band.dart';

/// A money figure found on the document.
final class AnalysisAmount {
  const AnalysisAmount({
    required this.label,
    required this.value,
    required this.currency,
    required this.confidence,
  });

  /// Arabic label, e.g. «إجمالي المبلغ».
  final String label;

  final double value;

  /// ISO-4217-ish code as the analysis reported it, e.g. `EGP`.
  final String currency;

  final ConfidenceBand confidence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisAmount &&
          other.label == label &&
          other.value == value &&
          other.currency == currency &&
          other.confidence == confidence;

  @override
  int get hashCode => Object.hash(label, value, currency, confidence);

  // Amount omitted on purpose — never log document figures (privacy §7).
  @override
  String toString() => 'AnalysisAmount($label, $currency, $confidence)';
}
