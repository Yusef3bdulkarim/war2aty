final class DocumentTypeDto {
  const DocumentTypeDto({
    required this.type,
    required this.title,
    required this.confidence,
  });

  factory DocumentTypeDto.fromJson(Map<String, dynamic> json) {
    return DocumentTypeDto(
      type: json['type'] as String,
      title: json['title'] as String,
      confidence: json['confidence'] as String,
    );
  }

  /// Raw wire enum — see API_CONTRACT §30.1. Mapped to a domain enum in T06.
  final String type;
  final String title;

  /// Raw wire enum — `high` | `medium` | `low` (§30.5).
  final String confidence;

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'confidence': confidence,
  };
}
