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

/// A clock reading, with the «الساعة» in front of it swallowed if the text
/// already wrote one (F30-T22) — the replacement puts exactly one back, so
/// «الساعة 14:30» no longer reads as «الساعة الساعة …». Spelled with either
/// final letter, since «الساعه» is how plenty of Egyptian text writes it and
/// OCR passes through whichever was printed.
final RegExp _timePattern = RegExp(
  '(?:الساع[ةه]\\s+)?($_digit{1,2}):($_digit{2})'
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
/// 2. `H:MM`, optionally preceded by «الساعة» and optionally followed by
///    `ص`/`م`/`AM`/`PM` → "الساعة … [و… دقيقة] صباحًا/مساءً". An «الساعة»
///    already in the text is swallowed rather than doubled, and a 24-hour
///    hour is read as the 12-hour one (`14:30` → "الساعة اثنين وثلاثين
///    دقيقة مساءً").
/// 3. A 10-11 digit contiguous run (phone numbers) → spoken digit-by-digit.
/// 4. A number preceded within a couple of words by a reference-number
///    keyword ("رقم"، "محضر"، "قضية"، "طلب"، "إيصال") → digit-by-digit.
/// 5. A number directly adjacent to a currency word ("جنيه"، "ج.م") →
///    Arabic number words (with hundreds/thousands agreement — 1200 →
///    "ألف ومئتين", 1500 → "ألف وخمسمائة", 10500 → "عشرة آلاف وخمسمائة",
///    1500000 → "مليون وخمسمائة ألف"). A decimal part reads as its own
///    number of قرش, *after* the currency word rather than before it —
///    «مئتين وخمسين جنيه وخمسين قرش» — and a zero one is dropped. A run too
///    long to be a real amount is left alone, under rule 6.
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
  result = result.replaceAllMapped(_currencyAfterPattern, (m) {
    final amount = _amountParts(m[1]!);
    if (amount == null) return m[0]!;
    return '${amount.whole} ${m[2]}${amount.piastres}';
  });
  result = result.replaceAllMapped(_currencyBeforePattern, (m) {
    final amount = _amountParts(m[2]!);
    if (amount == null) return m[0]!;
    return '${m[1]} ${amount.whole}${amount.piastres}';
  });
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

    final writtenPeriod = switch (m[3]) {
      null => '',
      'ص' => ' صباحًا',
      'م' => ' مساءً',
      'AM' || 'am' => ' صباحًا',
      'PM' || 'pm' => ' مساءً',
      final s when s.startsWith('صباح') => ' صباحًا',
      final s when s.startsWith('مساء') => ' مساءً',
      _ => '',
    };

    // A 24-hour hour, read as the 12-hour one an Egyptian ear expects
    // (F30-T22): «14:30» used to read as «أربعة عشر», which is not how
    // anybody says half past two. 13 and up are unambiguously afternoon and
    // 0 unambiguously morning, so those two get their period word even when
    // the paper wrote none — and a marker contradicting a 24-hour hour
    // («14:30 ص») loses to the clock, which cannot be misread.
    //
    // 1 to 12 keep today's behaviour exactly: the hour as written, and a
    // period word only if the paper carried one. Noon and midday stay
    // unqualified rather than guessed at.
    final (spokenHour, period) = switch (hour) {
      0 => (12, writtenPeriod.isEmpty ? ' صباحًا' : writtenPeriod),
      >= 13 => (hour - 12, ' مساءً'),
      _ => (hour, writtenPeriod),
    };

    // "on the hour" has no minute to join with "و" — everything else does.
    final minutePhrase = minute == 0
        ? ' تمامًا'
        : ' و${_arabicNumberWords(minute)} دقيقة';
    return 'الساعة ${_arabicNumberWords(spokenHour)}$minutePhrase$period';
  });
}

/// [numberText] (an integer, optionally with one `.`-separated decimal part)
/// split into the words for the pounds and the words for the piastres.
///
/// Handed back in two pieces rather than one string because the currency word
/// belongs *between* them — «مئتين وخمسين جنيه وخمسين قرش», not «مئتين
/// وخمسين وخمسين قرش جنيه» (F30-T21). Only the caller knows where the
/// currency word sat on the page, so only the caller can place it.
/// [piastres] is the whole suffix, ready to append, and empty when the amount
/// has no decimal part.
///
/// `null` for a run too long to speak, which leaves the digits on the page
/// untouched for the engine to read. The alternative is worse than useless:
/// [_parseDigits] wraps around silently past 2^63, so a 20-digit OCR smudge
/// would otherwise be read aloud, confidently, as a number the paper does not
/// carry — the invented figure CLAUDE.md §7 forbids.
({String whole, String piastres})? _amountParts(String numberText) {
  final parts = numberText.split('.');
  if (parts.any((part) => part.length > _maxSpokenDigits)) return null;
  final whole = _arabicNumberWords(_parseDigits(parts[0]));
  if (parts.length < 2 || parts[1].isEmpty) {
    return (whole: whole, piastres: '');
  }
  // `250.00` is two hundred and fifty pounds, full stop — reading "and zero
  // piastres" after it is noise, and this app is read aloud to people who
  // cannot easily re-read what they just heard.
  final piastres = _parseDigits(parts[1]);
  if (piastres == 0) return (whole: whole, piastres: '');
  return (whole: whole, piastres: ' و${_arabicNumberWords(piastres)} قرش');
}

/// [digits] (either script) read one at a time — the phone/reference-number
/// reading, as opposed to [_arabicNumberWords]'s single cardinal number.
String _digitByDigit(String digits) =>
    digits.split('').map((c) => _digitWords[_digitValue(c)]).join(' ');

/// The largest number spoken as words. Past this the digits are left for the
/// engine to read as it will: a figure that big on an Egyptian paper is far
/// likelier to be OCR noise — a meter serial read as one run, say — than a
/// real amount, and guessing at it is what rule 6 above refuses to do.
const int _spokenWordsLimit = 1000000000;

/// How many digits [_spokenWordsLimit] leaves room for — the widest run
/// [_amountWords] will turn into words.
const int _maxSpokenDigits = 9;

/// [n] as one Arabic cardinal number, up to (but not including)
/// [_spokenWordsLimit].
///
/// Total for every `int`: anything out of range comes back as its own digits
/// rather than throwing. It has to be, because the only caller that bounds
/// its input is the date rule (a 4-digit year) — [_amountWords] passes
/// whatever digits sat next to «جنيه», and OCR decides that, not us. Two
/// crashes lived here until F30-T02 for exactly that reason: `10500 جنيه`
/// threw `RangeError` and `1000000 جنيه` threw on a null check, both of them
/// killing the reading before a single word was spoken.
String _arabicNumberWords(int n) {
  if (n == 0) return 'صفر';
  if (n < 0 || n >= _spokenWordsLimit) return n.toString();

  final parts = [
    if (n ~/ 1000000 case final millions when millions > 0)
      _scaled(millions, 'مليون', 'مليونين', 'ملايين'),
    if ((n % 1000000) ~/ 1000 case final thousands when thousands > 0)
      _scaled(thousands, 'ألف', 'ألفين', 'آلاف'),
    if (_belowThousand(n % 1000) case final remainder when remainder.isNotEmpty)
      remainder,
  ];

  return parts.join(' و');
}

/// [count] of a scale word, with the agreement Arabic puts on it: one and two
/// have their own forms, 3-10 take the plural ([plural]), and 11 and up go
/// back to the singular ([singular]) — «ألفين»، «ثلاثة آلاف»، «أحد عشر ألف».
///
/// [count] is always 1-999 here: [_arabicNumberWords] caps the whole number
/// below [_spokenWordsLimit] before it divides, so [_belowThousand] below can
/// never be handed a number it has no hundreds entry for.
String _scaled(int count, String singular, String dual, String plural) =>
    switch (count) {
      1 => singular,
      2 => dual,
      <= 10 => '${_belowThousand(count)} $plural',
      _ => '${_belowThousand(count)} $singular',
    };

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
