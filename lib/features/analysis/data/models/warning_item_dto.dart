final class WarningItemDto {
  const WarningItemDto({required this.text, required this.type});

  factory WarningItemDto.fromJson(Map<String, dynamic> json) {
    return WarningItemDto(
      text: json['text'] as String,
      type: json['type'] as String,
    );
  }

  final String text;

  /// Raw wire enum — see API_CONTRACT §30.3.
  final String type;

  Map<String, dynamic> toJson() => {'text': text, 'type': type};
}
