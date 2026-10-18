/// Writes a Latin-script stretch of a reading in Arabic letters, so a device
/// with no English voice can still say it (F30-T17).
///
/// The fallback *inside* Option A (F30 locked decision 3). The queue speaks
/// each language run with a voice that can pronounce it, but a device is
/// free to have Arabic voices and no English one — and an Arabic voice has
/// no Latin grapheme rules, so handing it `invoice` makes it name the
/// characters one at a time, which is the owner's own symptom (F30 RC-4).
/// Written in Arabic letters the same word comes out as «إنفويس», which is
/// what someone reading the paper aloud would have said.
///
/// There is no counterpart the other way. Arabic written in Latin letters
/// would be unusable, so a device with no Arabic voice is told so instead
/// (F30-T07, locked decision 4).
///
/// **An approximation, and knowingly so.** English spelling does not say how
/// a word sounds, so nothing short of a pronunciation dictionary gets every
/// word right, and that is not what this is for: the bar is "a listener
/// recognises the word", not "a phonetician approves". Common English words
/// on an Egyptian paper — names, months, `invoice`, `total` — come out the
/// way an Egyptian would write them. The rest come out close enough to beat
/// being spelled letter by letter, which is the only alternative.
///
/// Synchronous and total, like the other two pieces of the queue's
/// preparation: rewriting a string cannot fail.
final class TransliterateLatinToArabic {
  const TransliterateLatinToArabic();

  /// [text] with every run of Latin letters rewritten in Arabic script.
  ///
  /// Everything else — digits, spaces, punctuation — passes through
  /// untouched. An Arabic voice reads a digit in Arabic already, which is
  /// what the number normalizer has prepared it to say.
  String call(String text) {
    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (!_isLatinLetter(text.codeUnitAt(i))) {
        out.writeCharCode(text.codeUnitAt(i));
        i++;
        continue;
      }
      var end = i;
      while (end < text.length && _isLatinLetter(text.codeUnitAt(end))) {
        end++;
      }
      out.write(_word(text.substring(i, end)));
      i = end;
    }
    return out.toString();
  }

  /// One word of Latin letters, in Arabic.
  static String _word(String token) {
    if (_isInitialism(token)) {
      return token.toLowerCase().split('').map(_letterName).join(' ');
    }

    final word = token.toLowerCase();
    final out = StringBuffer();
    var i = 0;
    while (i < word.length) {
      // A final `e` is usually silent — `name`, `invoice`, `before`. Only in
      // a word long enough to still say something without it: dropping it
      // from `the` would leave a single letter behind.
      if (i == word.length - 1 && word[i] == 'e' && word.length >= 4) break;

      // A final `er` is a single Arabic `ر`: «ميتر», «أكتوبر», «نمبر». Spelt
      // out it would become «ميتير», which is a syllable the word has not
      // got.
      if (i == word.length - 2 && word.length >= 4 && word.endsWith('er')) {
        out.write('ر');
        break;
      }

      final group = _groupAt(word, i);
      if (group != null) {
        out.write(group.sound);
        i += group.length;
        continue;
      }

      // English's silent `e` reaches back over one consonant and lengthens
      // the vowel before it — `name` is «نيم» and not «نام», `time` is
      // «تايم», `mobile` is «موبايل». Not over `c` or `g`, which soften
      // instead and leave the vowel short: `service`, `notice`, `message`.
      if (_lengthenedByASilentE(word, i)) {
        out.write(_lengthened[word[i]]!);
        i++;
        continue;
      }

      // `ll`, `tt`, `ss`: English doubles a consonant to mark the vowel
      // before it, and Arabic has no use for the second one. Vowel pairs are
      // not touched here — the table above has already taken `ee` and `oo`.
      if (i > 0 && word[i] == word[i - 1] && !_isVowel(word[i])) {
        i++;
        continue;
      }

      out.write(_letter(word, i));
      i++;
    }
    return out.toString();
  }

  /// The multi-letter spelling starting at [i], if there is one.
  ///
  /// Longest first, because `tion` has to be read before `ti` would be.
  static ({String sound, int length})? _groupAt(String word, int i) {
    for (final length in const [4, 3, 2]) {
      if (i + length > word.length) continue;
      final sound = _groups[word.substring(i, i + length)];
      if (sound != null) return (sound: sound, length: length);
    }
    return null;
  }

  /// Whether the vowel at [i] is the one a silent final `e` lengthens: the
  /// third letter from the end, with one consonant between it and the `e`.
  static bool _lengthenedByASilentE(String word, int i) {
    if (word.length < 4 || i != word.length - 3) return false;
    if (!_isVowel(word[i]) || word[i + 2] != 'e') return false;
    final between = word[i + 1];
    return !_isVowel(between) && between != 'c' && between != 'g';
  }

  /// One letter, in the Arabic the position asks for.
  static String _letter(String word, int i) {
    final letter = word[i];
    // Arabic cannot open a word on a bare vowel letter, so an initial vowel
    // carries an alef — `invoice` opens «إ», not «ي», which would have been
    // read as the consonant `y`.
    if (i == 0 && _opening.containsKey(letter)) return _opening[letter]!;
    // `c` is `s` before `e`, `i`, `y` — `invoice`, `city` — and `k`
    // everywhere else.
    if (letter == 'c') {
      final next = i + 1 < word.length ? word[i + 1] : '';
      return (next == 'e' || next == 'i' || next == 'y') ? 'س' : 'ك';
    }
    return _letters[letter] ?? '';
  }

  /// Whether [token] is read out letter by letter rather than as a word.
  ///
  /// `EGP`, `PDF`, `ID`: all capitals and short. Spelling those out is what a
  /// person does with them, and running them through the rules above would
  /// make an unpronounceable word of three consonants. Anything longer is
  /// treated as a word that happens to be shouted.
  static bool _isInitialism(String token) =>
      token.length >= 2 &&
      token.length <= 4 &&
      token == token.toUpperCase() &&
      token != token.toLowerCase();

  /// What a letter is called when a word is spelled out.
  static String _letterName(String letter) => switch (letter) {
    'a' => 'إيه',
    'b' => 'بي',
    'c' => 'سي',
    'd' => 'دي',
    'e' => 'إي',
    'f' => 'إف',
    'g' => 'جي',
    'h' => 'إتش',
    'i' => 'آي',
    'j' => 'جاي',
    'k' => 'كيه',
    'l' => 'إل',
    'm' => 'إم',
    'n' => 'إن',
    'o' => 'أو',
    'p' => 'بي',
    'q' => 'كيو',
    'r' => 'آر',
    's' => 'إس',
    't' => 'تي',
    'u' => 'يو',
    'v' => 'في',
    'w' => 'دبليو',
    'x' => 'إكس',
    'y' => 'واي',
    _ => 'زد',
  };

  /// Letter groups that are one sound, not the sum of their letters.
  static const _groups = <String, String>{
    'tion': 'شن',
    'tch': 'تش',
    'igh': 'اي',
    'sh': 'ش',
    'ch': 'تش',
    'th': 'ث',
    'ph': 'ف',
    'gh': 'غ',
    'kh': 'خ',
    'ck': 'ك',
    'qu': 'كو',
    'wh': 'و',
    'ng': 'نج',
    'ee': 'ي',
    'ea': 'ي',
    'ie': 'ي',
    'ey': 'ي',
    'oo': 'و',
    'oa': 'و',
    'au': 'و',
    'aw': 'و',
    'ou': 'او',
    'ow': 'او',
    'ai': 'اي',
    'ay': 'اي',
    'ei': 'اي',
    'oi': 'وي',
    'oy': 'وي',
  };

  /// A vowel a silent final `e` lengthens, and what it then sounds like.
  static const _lengthened = <String, String>{
    'a': 'ي',
    'e': 'ي',
    'i': 'اي',
    'o': 'و',
    'u': 'يو',
  };

  /// A vowel that opens a word, and the alef that has to carry it.
  static const _opening = <String, String>{
    'a': 'أ',
    'e': 'إ',
    'i': 'إ',
    'o': 'أو',
    'u': 'أ',
  };

  /// One Latin letter, one Arabic one. `p` and `v` have no Arabic letter of
  /// their own, and take the sound Egyptian Arabic gives them.
  static const _letters = <String, String>{
    'a': 'ا',
    'b': 'ب',
    'd': 'د',
    'e': 'ي',
    'f': 'ف',
    'g': 'ج',
    'h': 'ه',
    'i': 'ي',
    'j': 'ج',
    'k': 'ك',
    'l': 'ل',
    'm': 'م',
    'n': 'ن',
    'o': 'و',
    'p': 'ب',
    'q': 'ك',
    'r': 'ر',
    's': 'س',
    't': 'ت',
    'u': 'و',
    'v': 'ف',
    'w': 'و',
    'x': 'كس',
    'y': 'ي',
    'z': 'ز',
  };

  static bool _isVowel(String letter) => 'aeiou'.contains(letter);

  static bool _isLatinLetter(int codeUnit) =>
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);
}
