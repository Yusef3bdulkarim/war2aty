import '../entities/date_candidate.dart';

/// Extracts date candidates from normalized OCR text.
///
/// Supports:
/// - Numeric formats: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY (with optional
///   2-digit year). Day-first per Egyptian convention.
/// - Arabic month names: يناير..ديسمبر (full and common abbreviations).
/// - English month names: January..December, Jan..Dec.
/// - Hijri month names: محرم..ذو الحجة — detected with normalizedDate=null
///   and isAmbiguous=true.
///
/// Pure Dart, no external dependencies.
final class DateExtractor {
  const DateExtractor();

  List<DateCandidate> extract(String text) {
    final candidates = <DateCandidate>[];

    for (final match in _numericDatePattern.allMatches(text)) {
      final candidate = _parseNumericDate(match);
      if (candidate != null) candidates.add(candidate);
    }

    for (final match in _arabicMonthDatePattern.allMatches(text)) {
      final candidate = _parseArabicMonthDate(match);
      if (candidate != null) candidates.add(candidate);
    }

    for (final match in _englishMonthDatePattern.allMatches(text)) {
      final candidate = _parseEnglishMonthDate(match);
      if (candidate != null) candidates.add(candidate);
    }

    for (final match in _hijriPattern.allMatches(text)) {
      candidates.add(
        DateCandidate(rawText: match.group(0)!, isAmbiguous: true),
      );
    }

    return candidates;
  }

  // ---------------------------------------------------------------------------
  // Numeric dates: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
  // ---------------------------------------------------------------------------

  static final _numericDatePattern = RegExp(
    r'(\d{1,2})\s*[/\-\.]\s*(\d{1,2})\s*[/\-\.]\s*(\d{2,4})',
  );

  static DateCandidate? _parseNumericDate(RegExpMatch match) {
    final raw = match.group(0)!;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);

    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    final isAmbiguous = day <= 12 && month <= 12 && day != month;

    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) return null;

    return DateCandidate(
      rawText: raw,
      normalizedDate: date,
      isAmbiguous: isAmbiguous,
    );
  }

  // ---------------------------------------------------------------------------
  // Arabic Gregorian month names
  // ---------------------------------------------------------------------------

  static const _arabicMonths = <String, int>{
    'يناير': 1,
    'فبراير': 2,
    'مارس': 3,
    'أبريل': 4,
    'إبريل': 4,
    'ابريل': 4,
    'مايو': 5,
    'يونيو': 6,
    'يونيه': 6,
    'يوليو': 7,
    'يوليه': 7,
    'أغسطس': 8,
    'اغسطس': 8,
    'سبتمبر': 9,
    'أكتوبر': 10,
    'اكتوبر': 10,
    'نوفمبر': 11,
    'ديسمبر': 12,
  };

  static final _arabicMonthNames = _arabicMonths.keys.join('|');

  static final _arabicMonthDatePattern = RegExp(
    '(\\d{1,2})\\s*(?:من\\s+)?($_arabicMonthNames)\\s*(\\d{2,4})?',
  );

  static DateCandidate? _parseArabicMonthDate(RegExpMatch match) {
    final raw = match.group(0)!;
    final day = int.tryParse(match.group(1)!);
    final monthName = match.group(2)!;
    final yearStr = match.group(3);

    if (day == null || day < 1 || day > 31) return null;
    final month = _arabicMonths[monthName];
    if (month == null) return null;

    var year = yearStr != null ? int.tryParse(yearStr) : null;
    if (year != null && year < 100) year += 2000;

    DateTime? date;
    if (year != null) {
      date = DateTime(year, month, day);
      if (date.month != month || date.day != day) return null;
    }

    return DateCandidate(
      rawText: raw,
      normalizedDate: date,
      isAmbiguous: year == null,
    );
  }

  // ---------------------------------------------------------------------------
  // English month names
  // ---------------------------------------------------------------------------

  static const _englishMonths = <String, int>{
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'sept': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };

  static final _englishMonthNames = _englishMonths.keys.join('|');

  static final _englishMonthDatePattern = RegExp(
    '(\\d{1,2})\\s*(?:of\\s+)?($_englishMonthNames)\\s*(\\d{2,4})?',
    caseSensitive: false,
  );

  static DateCandidate? _parseEnglishMonthDate(RegExpMatch match) {
    final raw = match.group(0)!;
    final day = int.tryParse(match.group(1)!);
    final monthName = match.group(2)!.toLowerCase();
    final yearStr = match.group(3);

    if (day == null || day < 1 || day > 31) return null;
    final month = _englishMonths[monthName];
    if (month == null) return null;

    var year = yearStr != null ? int.tryParse(yearStr) : null;
    if (year != null && year < 100) year += 2000;

    DateTime? date;
    if (year != null) {
      date = DateTime(year, month, day);
      if (date.month != month || date.day != day) return null;
    }

    return DateCandidate(
      rawText: raw,
      normalizedDate: date,
      isAmbiguous: year == null,
    );
  }

  // ---------------------------------------------------------------------------
  // Hijri month detection (no conversion)
  // ---------------------------------------------------------------------------

  static const _hijriMonthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الاول',
    'ربيع الثاني',
    'ربيع الثانى',
    'جمادى الأولى',
    'جمادى الاولى',
    'جمادى الآخرة',
    'جمادى الاخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static final _hijriMonthNamesPattern = _hijriMonthNames.join('|');

  static final _hijriPattern = RegExp(
    '\\d{1,2}\\s*(?:من\\s+)?(?:$_hijriMonthNamesPattern)\\s*\\d{2,4}',
  );
}
