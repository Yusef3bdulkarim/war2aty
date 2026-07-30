import '../entities/time_candidate.dart';

/// Extracts time candidates from normalized OCR text.
///
/// Supports:
/// - 24h format: HH:MM, HH.MM
/// - 12h format with Arabic markers: صباحاً/ص (AM), مساءً/م (PM)
/// - 12h format with English markers: AM/PM, a.m./p.m.
///
/// Pure Dart, no external dependencies.
final class TimeExtractor {
  const TimeExtractor();

  List<TimeCandidate> extract(String text) {
    final candidates = <TimeCandidate>[];

    for (final match in _timePattern.allMatches(text)) {
      final candidate = _parseTime(match);
      if (candidate != null) candidates.add(candidate);
    }

    return candidates;
  }

  static final _timePattern = RegExp(
    r'(\d{1,2})\s*[:\.]\s*(\d{2})'
    r'(?:\s*'
    r'(صباح[اً]*|مساء[ًا]*|ص|م|[AaPp]\.?[Mm]\.?)'
    r')?',
  );

  static TimeCandidate? _parseTime(RegExpMatch match) {
    final raw = match.group(0)!;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final period = match.group(3)?.trim();

    if (hour == null || minute == null) return null;
    if (minute > 59) return null;

    var isAmbiguous = false;

    if (period != null) {
      final isPm = _isPmMarker(period);
      final isAm = _isAmMarker(period);

      if (hour < 1 || hour > 12) return null;

      if (isPm && hour != 12) {
        hour += 12;
      } else if (isAm && hour == 12) {
        hour = 0;
      }
    } else {
      if (hour > 23) return null;
      // Without AM/PM, times 1:00–12:59 are ambiguous (could be AM or PM).
      if (hour >= 1 && hour <= 12) isAmbiguous = true;
    }

    return TimeCandidate(
      rawText: raw,
      hour: hour,
      minute: minute,
      isAmbiguous: isAmbiguous,
    );
  }

  static bool _isPmMarker(String marker) {
    final lower = marker.toLowerCase();
    return lower.startsWith('مساء') ||
        lower == 'م' ||
        lower.startsWith('pm') ||
        lower.startsWith('p.m');
  }

  static bool _isAmMarker(String marker) {
    final lower = marker.toLowerCase();
    return lower.startsWith('صباح') ||
        lower == 'ص' ||
        lower.startsWith('am') ||
        lower.startsWith('a.m');
  }
}
