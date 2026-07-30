/// A date found by rule-based extraction from normalized OCR text.
///
/// Pure Dart, no Flutter import.
final class DateCandidate {
  const DateCandidate({
    required this.rawText,
    this.normalizedDate,
    this.isAmbiguous = false,
  });

  /// The matched substring from the normalized text.
  final String rawText;

  /// Parsed Gregorian date, or `null` when parsing failed or the date is
  /// Hijri (detected but not converted).
  final DateTime? normalizedDate;

  /// True when the format is ambiguous (e.g. DD and MM both ≤ 12) or when
  /// the date is Hijri.
  final bool isAmbiguous;

  @override
  bool operator ==(Object other) =>
      other is DateCandidate &&
      other.rawText == rawText &&
      other.normalizedDate == normalizedDate &&
      other.isAmbiguous == isAmbiguous;

  @override
  int get hashCode => Object.hash(rawText, normalizedDate, isAmbiguous);

  @override
  String toString() =>
      'DateCandidate($rawText, date=$normalizedDate, '
      'ambiguous=$isAmbiguous)';
}
