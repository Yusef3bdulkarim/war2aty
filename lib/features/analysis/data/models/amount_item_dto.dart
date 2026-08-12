final class AmountItemDto {
  const AmountItemDto({
    required this.label,
    required this.value,
    required this.currency,
    required this.confidence,
    this.rawValue,
  });

  factory AmountItemDto.fromJson(Map<String, dynamic> json) {
    return AmountItemDto(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      currency: json['currency'] as String,
      confidence: json['confidence'] as String,
      rawValue: json['rawValue'] as String?,
    );
  }

  final String label;
  final double value;
  final String currency;

  /// Raw wire enum — `high` | `medium` | `low` (§30.5).
  final String confidence;

  /// Literal text this amount was matched from; `null` when inferred.
  /// `rawValue` is camelCase on the wire — the one field on this object that
  /// isn't snake_case (API_CONTRACT §30 v2, F13-T17).
  final String? rawValue;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'currency': currency,
    'confidence': confidence,
    'rawValue': rawValue,
  };
}
