/// A time found by rule-based extraction from normalized OCR text.
///
/// Pure Dart, no Flutter import.
final class TimeCandidate {
  const TimeCandidate({
    required this.rawText,
    required this.hour,
    required this.minute,
    this.isAmbiguous = false,
  });

  /// The matched substring from the normalized text.
  final String rawText;

  /// Hour in 24-hour format (0–23).
  final int hour;

  /// Minute (0–59).
  final int minute;

  final bool isAmbiguous;

  @override
  bool operator ==(Object other) =>
      other is TimeCandidate &&
      other.rawText == rawText &&
      other.hour == hour &&
      other.minute == minute &&
      other.isAmbiguous == isAmbiguous;

  @override
  int get hashCode => Object.hash(rawText, hour, minute, isAmbiguous);

  @override
  String toString() =>
      'TimeCandidate($rawText, ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}, ambiguous=$isAmbiguous)';
}
