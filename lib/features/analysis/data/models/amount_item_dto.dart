final class AmountItemDto {
  const AmountItemDto({
    required this.label,
    required this.value,
    required this.currency,
    required this.confidence,
  });

  factory AmountItemDto.fromJson(Map<String, dynamic> json) {
    return AmountItemDto(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      currency: json['currency'] as String,
      confidence: json['confidence'] as String,
    );
  }

  final String label;
  final double value;
  final String currency;

  /// Raw wire enum — `high` | `medium` | `low` (§30.5).
  final String confidence;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'currency': currency,
    'confidence': confidence,
  };
}
