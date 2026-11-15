final class PaperTime {
  const PaperTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  int get minuteOfDay => hour * 60 + minute;

  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'PaperTime(hh:mm)';
}

final class PaperDate {
  const PaperDate({required this.day, this.time, required this.text});

  final DateTime day;
  final PaperTime? time;
  final String text;

  int? get minuteOfDay => time?.minuteOfDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperDate &&
          other.day == day &&
          other.time == time &&
          other.text == text;

  @override
  int get hashCode => Object.hash(day, time, text);

  @override
  String toString() =>
      'PaperDate(hasTime: ${time != null}, ${text.length} chars)';
}
