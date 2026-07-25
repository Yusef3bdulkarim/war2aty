import 'confidence_band.dart';

/// Where a value came from.
enum InfoSource {
  /// Read directly off the document text.
  extracted,

  /// Worked out by the analysis rather than written on the paper.
  ///
  /// Inferred values always show a basis indicator in the UI, whatever their
  /// [ConfidenceBand] (API_CONTRACT §30.5).
  inferred,
}

/// One labelled fact pulled off the document — account number, meter reading,
/// patient name, and so on.
final class KeyInformation {
  const KeyInformation({
    required this.label,
    required this.value,
    required this.confidence,
    required this.source,
  });

  /// Arabic label for the field, e.g. «رقم الحساب».
  final String label;

  /// The value as text — kept as written so nothing is silently reformatted.
  final String value;

  final ConfidenceBand confidence;
  final InfoSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyInformation &&
          other.label == label &&
          other.value == value &&
          other.confidence == confidence &&
          other.source == source;

  @override
  int get hashCode => Object.hash(label, value, confidence, source);

  // Deliberately does not print [value]: entity toStrings end up in error
  // reports, and document contents must never be logged (privacy §7).
  @override
  String toString() => 'KeyInformation($label, $confidence, $source)';
}
