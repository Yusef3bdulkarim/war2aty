final class DateItemDto {
  const DateItemDto({
    required this.label,
    required this.date,
    this.time,
    required this.role,
    required this.isReminderWorthy,
    required this.confidence,
  });

  factory DateItemDto.fromJson(Map<String, dynamic> json) {
    return DateItemDto(
      label: json['label'] as String,
      date: json['date'] as String,
      time: json['time'] as String?,
      role: json['role'] as String,
      isReminderWorthy: json['is_reminder_worthy'] as bool,
      confidence: json['confidence'] as String,
    );
  }

  final String label;

  /// ISO-8601 date (`yyyy-MM-dd`) as sent on the wire.
  final String date;

  /// `HH:mm`, or null when the document carries no time.
  final String? time;

  /// Raw wire enum — see API_CONTRACT §30.2.
  final String role;
  final bool isReminderWorthy;

  /// Raw wire enum — `high` | `medium` | `low` (§30.5).
  final String confidence;

  Map<String, dynamic> toJson() => {
    'label': label,
    'date': date,
    'time': time,
    'role': role,
    'is_reminder_worthy': isReminderWorthy,
    'confidence': confidence,
  };
}
