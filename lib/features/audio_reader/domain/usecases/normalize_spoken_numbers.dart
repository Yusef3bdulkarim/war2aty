/// One digit, Western (`0`-`9`) or Arabic-Indic (`٠`-`٩`), as a spoken Arabic
/// word — used everywhere a number is read digit-by-digit rather than as one
/// cardinal (phone numbers, reference/case numbers).
const List<String> _digitWords = [
  'صفر',
  'واحد',
  'اثنين',
  'ثلاثة',
  'أربعة',
  'خمسة',
  'ستة',
  'سبعة',
  'ثمانية',
  'تسعة',
];

/// 1-9 as the word used inside a compound number (index 0 is unused —
/// compound numbers never spell out a bare zero digit).
const List<String> _ones = [
  '',
  'واحد',
  'اثنين',
  'ثلاثة',
  'أربعة',
  'خمسة',
  'ستة',
  'سبعة',
  'ثمانية',
  'تسعة',
];

/// 10-19, index 0 mapping to 10.
const List<String> _teens = [
  'عشرة',
  'أحد عشر',
  'اثنا عشر',
  'ثلاثة عشر',
  'أربعة عشر',
  'خمسة عشر',
  'ستة عشر',
  'سبعة عشر',
  'ثمانية عشر',
  'تسعة عشر',
];

const Map<int, String> _tens = {
  20: 'عشرين',
  30: 'ثلاثين',
  40: 'أربعين',
  50: 'خمسين',
  60: 'ستين',
  70: 'سبعين',
  80: 'ثمانين',
  90: 'تسعين',
};

const Map<int, String> _hundreds = {
  100: 'مئة',
  200: 'مئتين',
  300: 'ثلاثمائة',
  400: 'أربعمائة',
  500: 'خمسمائة',
  600: 'ستمائة',
  700: 'سبعمائة',
  800: 'ثمانمائة',
  900: 'تسعمائة',
};

const List<String> _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Any single digit, either script — the character class every pattern below
/// is built out of, since OCR'd Arabic text can carry either.
const String _digit = '[0-9٠-٩]';

/// A digit run not immediately touching another digit — used so a longer
/// number is never partially matched as a shorter one.
final RegExp _phoneNumberPattern = RegExp(
  '(^|[^0-9٠-٩])($_digit{10,11})(?=\$|[^0-9٠-٩])',
);

final RegExp _datePattern = RegExp(
  '($_digit{1,2})[/-]($_digit{1,2})[/-]($_digit{4})(?=\$|[^0-9٠-٩])',
);

final RegExp _timePattern = RegExp(
  '($_digit{1,2}):($_digit{2})'
  r'\s*(صباح\S*|مساء\S*|ص(?![ء-ي])|م(?![ء-ي])|AM|PM|am|pm)?',
);

final RegExp _referenceNumberPattern = RegExp(
  '(رقم|محضر|قضية|طلب|إيصال)(?:\\s+\\S+){0,2}?\\s+($_digit+)(?=\$|[^0-9٠-٩])',
);

final RegExp _currencyAfterPattern = RegExp(
  '($_digit+(?:\\.$_digit+)?)\\s*(جنيه|ج\\.م)',
);

final RegExp _currencyBeforePattern = RegExp(
  '(جنيه|ج\\.م)\\s*($_digit+(?:\\.$_digit+)?)',
);

/// Speaks numbers the way the surrounding Arabic text means them, instead of
/// letting the TTS engine read every digit run as one plain cardinal number.
///
/// Applied once, right before speaking, inside `BuildReadingText.call()` —
/// the single place every reading mode's text passes through, so every
/// number spoken by the app goes through the same rules.
///
/// Rules, most specific first — once a number is consumed by an earlier
/// rule it is no longer plain digits, so a later rule can never re-match it:
/// 1. `DD/MM/YYYY` or `DD-MM-YYYY` → day as a plain number (the engine
///    already reads a short bare number correctly) + Arabic month name +
///    year spelled out in words (a bare 4-digit run reads naturally as
///    digit-by-digit, which is wrong for a year).
/// 2. `H:MM`, optionally followed by `ص`/`م`/`AM`/`PM` → "الساعة … [و…
///    دقيقة] صباحًا/مساءً".
/// 3. A 10-11 digit contiguous run (phone numbers) → spoken digit-by-digit.
/// 4. A number preceded within a couple of words by a reference-number
///    keyword ("رقم"، "محضر"، "قضية"، "طلب"، "إيصال") → digit-by-digit.
/// 5. A number directly adjacent to a currency word ("جنيه"، "ج.م") →
///    Arabic number words (with hundreds/thousands agreement — 1200 →
///    "ألف ومئتين", 1500 → "ألف وخمسمائة"); a decimal part reads as its own
///    number of قرش.
/// 6. Anything else passes through unchanged — no guessing on genuinely
///    ambiguous input.
String normalizeSpokenNumbers(String text) {
  var result = text;
  result = _normalizeDates(result);
  result = _normalizeTimes(result);
  result = result.replaceAllMapped(
    _phoneNumberPattern,
    (m) => '${m[1]}${_digitByDigit(m[2]!)}',
  );
  result = result.replaceAllMapped(_referenceNumberPattern, (m) {
    // The digits are always the tail of the match — everything in between
    // the keyword and the number (e.g. "الحساب:") must survive untouched.
    final digits = m[2]!;
    final prefix = m[0]!.substring(0, m[0]!.length - digits.length);
    return '$prefix${_digitByDigit(digits)}';
  });
  result = result.replaceAllMapped(
    _currencyAfterPattern,
    (m) => '${_amountWords(m[1]!)} ${m[2]}',
  );
  result = result.replaceAllMapped(
    _currencyBeforePattern,
    (m) => '${m[1]} ${_amountWords(m[2]!)}',
  );
  return result;
}

String _normalizeDates(String text) {
  return text.replaceAllMapped(_datePattern, (m) {
    final day = _parseDigits(m[1]!);
    final month = _parseDigits(m[2]!);
    final year = _parseDigits(m[3]!);
    // Out of calendar range: this was never a date, leave it untouched
    // rather than guessing.
    if (day < 1 || day > 31 || month < 1 || month > 12) return m[0]!;
    return '$day ${_months[month - 1]} ${_arabicNumberWords(year)}';
  });
}

String _normalizeTimes(String text) {
  return text.replaceAllMapped(_timePattern, (m) {
    final hour = _parseDigits(m[1]!);
    final minute = _parseDigits(m[2]!);
    if (hour > 23 || minute > 59) return m[0]!;

    final period = switch (m[3]) {
      null => '',
      'ص' => ' صباحًا',
      'م' => ' مساءً',
      'AM' || 'am' => ' صباحًا',
      'PM' || 'pm' => ' مساءً',
      final s when s.startsWith('صباح') => ' صباحًا',
      final s when s.startsWith('مساء') => ' مساءً',
      _ => '',
    };

    // "on the hour" has no minute to join with "و" — everything else does.
    final minutePhrase = minute == 0
        ? ' تمامًا'
        : ' و${_arabicNumberWords(minute)} دقيقة';
    return 'الساعة ${_arabicNumberWords(hour)}$minutePhrase$period';
  });
}

/// [numberText] (an integer, optionally with one `.`-separated decimal part)
/// as Arabic number words. The decimal part, if present, reads as its own
/// number of قرش.
String _amountWords(String numberText) {
  final parts = numberText.split('.');
  final whole = _arabicNumberWords(_parseDigits(parts[0]));
  if (parts.length < 2 || parts[1].isEmpty) return whole;
  return '$whole و${_arabicNumberWords(_parseDigits(parts[1]))} قرش';
}

/// [digits] (either script) read one at a time — the phone/reference-number
/// reading, as opposed to [_arabicNumberWords]'s single cardinal number.
String _digitByDigit(String digits) =>
    digits.split('').map((c) => _digitWords[_digitValue(c)]).join(' ');

/// [n] as one Arabic cardinal number, up to the low hundred-thousands —
/// comfortably past anything a currency amount or a calendar year needs.
String _arabicNumberWords(int n) {
  if (n == 0) return 'صفر';

  final thousands = n ~/ 1000;
  final remainder = n % 1000;

  final String thousandsWord;
  if (thousands == 0) {
    thousandsWord = '';
  } else if (thousands == 1) {
    thousandsWord = 'ألف';
  } else if (thousands == 2) {
    thousandsWord = 'ألفين';
  } else if (thousands <= 10) {
    thousandsWord = '${_ones[thousands]} آلاف';
  } else {
    thousandsWord = '${_belowThousand(thousands)} ألف';
  }

  final remainderWord = _belowThousand(remainder);
  if (thousandsWord.isEmpty) return remainderWord;
  if (remainderWord.isEmpty) return thousandsWord;
  return '$thousandsWord و$remainderWord';
}

/// [n] (0-999) as Arabic number words, with hundreds/tens/ones agreement.
String _belowThousand(int n) {
  if (n == 0) return '';

  final hundredDigit = (n ~/ 100) * 100;
  final remainder = n % 100;

  final hundredWord = hundredDigit == 0 ? '' : _hundreds[hundredDigit]!;

  final String remainderWord;
  if (remainder == 0) {
    remainderWord = '';
  } else if (remainder < 10) {
    remainderWord = _ones[remainder];
  } else if (remainder < 20) {
    remainderWord = _teens[remainder - 10];
  } else {
    final tensDigit = (remainder ~/ 10) * 10;
    final onesDigit = remainder % 10;
    remainderWord = onesDigit == 0
        ? _tens[tensDigit]!
        : '${_ones[onesDigit]} و${_tens[tensDigit]}';
  }

  if (hundredWord.isEmpty) return remainderWord;
  if (remainderWord.isEmpty) return hundredWord;
  return '$hundredWord و$remainderWord';
}

/// [digits] (either script) parsed as a plain integer.
int _parseDigits(String digits) =>
    digits.split('').map(_digitValue).fold(0, (acc, d) => acc * 10 + d);

/// One digit character (either script) as its 0-9 value.
int _digitValue(String char) {
  final code = char.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) return code - 0x30; // '0'-'9'
  if (code >= 0x660 && code <= 0x669) return code - 0x660; // '٠'-'٩'
  throw ArgumentError('Not a digit: $char');
}
