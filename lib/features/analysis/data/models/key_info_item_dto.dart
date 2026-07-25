final class KeyInfoItemDto {
  const KeyInfoItemDto({
    required this.label,
    required this.value,
    required this.confidence,
    required this.source,
  });

  factory KeyInfoItemDto.fromJson(Map<String, dynamic> json) {
    return KeyInfoItemDto(
      label: json['label'] as String,
      value: json['value'] as String,
      confidence: json['confidence'] as String,
      source: json['source'] as String,
    );
  }

  final String label;
  final String value;

  /// Raw wire enum — `high` | `medium` | `low` (§30.5).
  final String confidence;

  /// Raw wire enum — `extracted` | `inferred` (§30.5).
  final String source;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'confidence': confidence,
    'source': source,
  };
}
