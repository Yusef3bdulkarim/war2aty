import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/transliterate_latin_to_arabic.dart';

/// F30-T17, the fallback inside Option A (F30 locked decision 3). A device
/// may have Arabic voices and no English one, and an Arabic voice handed
/// Latin script names the characters one at a time — the owner's «English
/// inside an Arabic paper is read letter-by-letter» (F30 RC-4).
///
/// The bar these assertions hold it to is "an Egyptian listener recognises
/// the word", not phonetic correctness: English spelling does not say how a
/// word sounds, and the alternative is being spelled out letter by letter.
void main() {
  const transliterate = TransliterateLatinToArabic();

  group('TransliterateLatinToArabic · words off a real paper', () {
    test('the words an Egyptian bill actually carries', () {
      expect(transliterate('invoice'), 'إنفويس');
      expect(transliterate('total'), 'توتال');
      expect(transliterate('balance'), 'بالانس');
      expect(transliterate('service'), 'سيرفيس');
      expect(transliterate('date'), 'ديت');
      expect(transliterate('mobile'), 'موبايل');
      expect(transliterate('internet'), 'إنتيرنيت');
    });

    test('names and brands', () {
      expect(transliterate('Vodafone'), 'فودافون');
      expect(transliterate('Cairo'), 'كايرو');
      expect(transliterate('Orange'), 'أورانج');
      expect(transliterate('Egypt'), 'إجيبت');
    });

    test('a whole English phrase, spaces and all', () {
      expect(transliterate('Pay before Friday'), 'باي بيفور فريداي');
    });
  });

  group('TransliterateLatinToArabic · the rules behind that', () {
    test('a word cannot open on a bare vowel letter', () {
      // «ي» at the start of an Arabic word is the consonant `y`, so an
      // initial vowel has to carry an alef.
      expect(transliterate('invoice'), startsWith('إ'));
      expect(transliterate('amount'), startsWith('أ'));
      expect(transliterate('October'), startsWith('أو'));
    });

    test('letter groups that are one sound, not two letters', () {
      expect(transliterate('show'), 'شاو');
      expect(transliterate('March'), 'مارتش');
      expect(transliterate('think'), 'ثينك');
      expect(transliterate('phone'), 'فون');
      expect(transliterate('station'), 'ستاشن');
      expect(transliterate('light'), 'لايت');
    });

    test('a silent final e lengthens the vowel before it', () {
      // «نام» would be a different word; the `e` is what makes it «نيم».
      expect(transliterate('name'), 'نيم');
      expect(transliterate('time'), 'تايم');
      expect(transliterate('home'), 'هوم');
    });

    test('except over a soft c, where the vowel stays short', () {
      expect(transliterate('notice'), 'نوتيس');
      expect(transliterate('office'), 'أوفيس');
    });

    test('a final er is one Arabic letter, not a syllable of its own', () {
      expect(transliterate('meter'), 'ميتر');
      expect(transliterate('number'), 'نومبر');
      expect(transliterate('October'), 'أوكتوبر');
      // Too short for the rule: dropping the vowel would leave «هر».
      expect(transliterate('her'), 'هير');
    });

    test('c is s before e, i and y, and k everywhere else', () {
      expect(transliterate('city'), 'سيتي');
      expect(transliterate('cut'), 'كوت');
    });

    test('a doubled consonant is written once', () {
      expect(transliterate('bill'), 'بيل');
      expect(transliterate('address'), 'أدريس');
    });

    test('case does not change the word', () {
      expect(transliterate('TOTALS'), transliterate('totals'));
      expect(transliterate('Invoice'), transliterate('invoice'));
    });
  });

  group('TransliterateLatinToArabic · short capitals are spelled out', () {
    test('an initialism is read letter by letter', () {
      // Run through the word rules, `EGP` would become three consonants
      // with nothing to say them with.
      expect(transliterate('EGP'), 'إي جي بي');
      expect(transliterate('PDF'), 'بي دي إف');
      expect(transliterate('ID'), 'آي دي');
    });

    test('a longer shout is still a word', () {
      expect(transliterate('TOTAL'), 'توتال');
    });

    test('a single capital is a word, not an initialism', () {
      expect(transliterate('A'), 'أ');
    });
  });

  group('TransliterateLatinToArabic · what it leaves alone', () {
    test('digits and punctuation are untouched', () {
      // An Arabic voice reads a digit in Arabic already — which is what the
      // number normalizer has prepared it to say.
      expect(transliterate('Pay 500 EGP'), 'باي 500 إي جي بي');
      expect(transliterate('15/03 - 2026'), '15/03 - 2026');
    });

    test('text with no Latin letters comes back exactly as it was', () {
      const arabic = 'فاتورة كهرباء ٥٠٠ جنيه';

      expect(transliterate(arabic), arabic);
      expect(transliterate(''), '');
    });

    test('an Arabic word beside an English one keeps its own letters', () {
      // The segmenter hands whole runs over, but nothing here depends on
      // that: Arabic script is not something this rewrites.
      expect(transliterate('فاتورة invoice'), 'فاتورة إنفويس');
    });
  });
}
