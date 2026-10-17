import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/audio_reader/domain/entities/language_run.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/segment_language_runs.dart';

const _segment = SegmentLanguageRuns();

/// The runs' languages in order, which most expectations are about.
List<ReadingLanguage> _languagesOf(List<LanguageRun> runs) => [
  for (final run in runs) run.language,
];

void main() {
  group('SegmentLanguageRuns', () {
    test('answers no runs at all for an empty reading', () {
      expect(_segment(''), isEmpty);
    });

    test('keeps a wholly Arabic reading as one Arabic run', () {
      const text = 'فاتورة كهرباء لازم تتدفع قبل الموعد.';

      expect(_segment(text), const [
        LanguageRun(text: text, language: ReadingLanguage.arabic),
      ]);
    });

    test('keeps a wholly English reading as one English run', () {
      const text = 'The bill is due on the 15th.';

      expect(_segment(text), const [
        LanguageRun(text: text, language: ReadingLanguage.english),
      ]);
    });

    test('splits an Arabic reading at an English word inside it', () {
      // The owner's symptom: "invoice" used to be read letter-by-letter by
      // the Arabic voice that read the rest of the sentence (F30 RC-4).
      final runs = _segment('فاتورة invoice لازم تتدفع');

      expect(runs, const [
        LanguageRun(text: 'فاتورة', language: ReadingLanguage.arabic),
        LanguageRun(text: ' invoice', language: ReadingLanguage.english),
        LanguageRun(text: ' لازم تتدفع', language: ReadingLanguage.arabic),
      ]);
    });

    test('splits an English reading at an Arabic word inside it', () {
      final runs = _segment('Pay مصر before Friday');

      expect(runs, const [
        LanguageRun(text: 'Pay', language: ReadingLanguage.english),
        LanguageRun(text: ' مصر', language: ReadingLanguage.arabic),
        LanguageRun(text: ' before Friday', language: ReadingLanguage.english),
      ]);
    });

    test('gives every alternation a run of its own, in reading order', () {
      final runs = _segment('أهلا hello أهلا hello');

      expect(_languagesOf(runs), const [
        ReadingLanguage.arabic,
        ReadingLanguage.english,
        ReadingLanguage.arabic,
        ReadingLanguage.english,
      ]);
    });

    test('a one-letter English run is still its own run', () {
      // Correct rather than tidy: an English voice names "C" as "see",
      // which is what that character means, while an Arabic voice would
      // make nothing of it.
      final runs = _segment('درجة C كل يوم');

      expect(runs, const [
        LanguageRun(text: 'درجة', language: ReadingLanguage.arabic),
        LanguageRun(text: ' C', language: ReadingLanguage.english),
        LanguageRun(text: ' كل يوم', language: ReadingLanguage.arabic),
      ]);
    });
  });

  // Digits, spaces and punctuation read the same in either voice, so they
  // never justify a run — or a gap between queue items — of their own.
  group('SegmentLanguageRuns and neutral characters', () {
    test('keeps digits inside the Arabic sentence they sit in', () {
      const text = 'المبلغ 500 جنيه، والموعد 2026/04/15.';

      expect(_segment(text), const [
        LanguageRun(text: text, language: ReadingLanguage.arabic),
      ]);
    });

    test('binds a neutral stretch between languages to the run after it', () {
      // "15 March" is an English date, so the 15 goes with March.
      expect(_segment('ادفع قبل 15 March'), const [
        LanguageRun(text: 'ادفع قبل', language: ReadingLanguage.arabic),
        LanguageRun(text: ' 15 March', language: ReadingLanguage.english),
      ]);

      // And the mirror image: the 500 goes with جنيه.
      expect(_segment('Total 500 جنيه'), const [
        LanguageRun(text: 'Total', language: ReadingLanguage.english),
        LanguageRun(text: ' 500 جنيه', language: ReadingLanguage.arabic),
      ]);
    });

    test('opens the first run with a neutral stretch before any letter', () {
      expect(_segment('500 جنيه'), const [
        LanguageRun(text: '500 جنيه', language: ReadingLanguage.arabic),
      ]);
    });

    test('closes the last run with the neutral tail after it', () {
      expect(_segment('المبلغ 500'), const [
        LanguageRun(text: 'المبلغ 500', language: ReadingLanguage.arabic),
      ]);
    });

    test('reads a text with no letters at all in Arabic, as one run', () {
      // A bare reference number or date: nobody's language in particular,
      // and Arabic is the app's own.
      const text = '2026/04/15 - 123456';

      expect(_segment(text), const [
        LanguageRun(text: text, language: ReadingLanguage.arabic),
      ]);
    });

    test('counts Arabic-Indic digits as Arabic, not as neutral', () {
      expect(_segment('٥٠٠'), const [
        LanguageRun(text: '٥٠٠', language: ReadingLanguage.arabic),
      ]);
    });

    test('never splits a surrogate pair across two runs', () {
      // Both halves are neutral, so an emoji cannot be torn in two — which
      // is what keeps the runs a faithful slicing of the reading.
      final runs = _segment('تم ✅👍 done');

      expect(runs.map((run) => run.text).join(), 'تم ✅👍 done');
      expect(runs, const [
        LanguageRun(text: 'تم', language: ReadingLanguage.arabic),
        LanguageRun(text: ' ✅👍 done', language: ReadingLanguage.english),
      ]);
    });

    test('keeps a surrogate pair whole when the languages change at it', () {
      // The case the run boundary could actually have torn: both halves of
      // the pair are neutral, so the cut has to land before them or after
      // them, never between.
      expect(_segment('a👍ب'), const [
        LanguageRun(text: 'a', language: ReadingLanguage.english),
        LanguageRun(text: '👍ب', language: ReadingLanguage.arabic),
      ]);
    });
  });

  // The three properties F30-T11's queue and F30-T13's progress lean on. A
  // run's offset into the reading is the sum of the lengths before it, which
  // only holds while the runs are an exact slicing of the text.
  group('SegmentLanguageRuns guarantees', () {
    const readings = [
      '',
      'فاتورة كهرباء',
      'Electricity bill',
      'فاتورة invoice لازم تتدفع قبل 15 March 2026، المبلغ 500 جنيه.',
      '   ',
      '123',
      'a',
      'ا',
      'ا1b2ا3b',
      'تم ✅👍 done',
      'a👍ب',
      // An Arabic presentation form, which `ofCodeUnit` classifies as
      // neutral rather than Arabic — as the regexes it replaced also did.
      // Here to prove the three guarantees survive a character the
      // classifier does not recognise, not to bless that gap.
      'ﭐabcا',
      'رقم المحضر ١٢٣ — ref. ABC/٤٥٦',
    ];

    test('the runs always concatenate back to the reading', () {
      for (final reading in readings) {
        expect(
          _segment(reading).map((run) => run.text).join(),
          reading,
          reason: 'segmenting "$reading" lost or moved text',
        );
      }
    });

    test('no run is ever empty', () {
      for (final reading in readings) {
        for (final run in _segment(reading)) {
          expect(run.text, isNotEmpty, reason: 'from "$reading"');
        }
      }
    });

    test('no two neighbouring runs share a language', () {
      for (final reading in readings) {
        final languages = _languagesOf(_segment(reading));
        for (var i = 1; i < languages.length; i++) {
          expect(
            languages[i],
            isNot(languages[i - 1]),
            reason: 'runs $i and ${i - 1} of "$reading" could be one run',
          );
        }
      }
    });
  });

  group('ReadingLanguage', () {
    test('carries the locale prefix a voice for the run must match', () {
      expect(ReadingLanguage.arabic.code, 'ar');
      expect(ReadingLanguage.english.code, 'en');
    });

    test('classifies the Arabic block and the Arabic Supplement as Arabic', () {
      for (final character in ['ا', 'ي', '٥', '،', '؟', 'ݐ', 'ݿ']) {
        expect(
          ReadingLanguage.ofCodeUnit(character.codeUnitAt(0)),
          ReadingLanguage.arabic,
          reason: 'for "$character"',
        );
      }
    });

    test('classifies Latin letters as English, in both cases', () {
      for (final character in ['A', 'Z', 'a', 'z']) {
        expect(
          ReadingLanguage.ofCodeUnit(character.codeUnitAt(0)),
          ReadingLanguage.english,
          reason: 'for "$character"',
        );
      }
    });

    test('classifies digits, spaces and punctuation as neutral', () {
      for (final character in ['0', '9', ' ', '\n', '.', '/', '-', '%']) {
        expect(
          ReadingLanguage.ofCodeUnit(character.codeUnitAt(0)),
          isNull,
          reason: 'for "$character"',
        );
      }
    });
  });

  group('LanguageRun', () {
    test('is equal to another run with the same text and language', () {
      const run = LanguageRun(text: 'فاتورة', language: ReadingLanguage.arabic);

      expect(
        run,
        const LanguageRun(text: 'فاتورة', language: ReadingLanguage.arabic),
      );
      expect(
        run.hashCode,
        const LanguageRun(
          text: 'فاتورة',
          language: ReadingLanguage.arabic,
        ).hashCode,
      );
      expect(
        run,
        isNot(
          const LanguageRun(text: 'فاتورة', language: ReadingLanguage.english),
        ),
      );
      expect(
        run,
        isNot(
          const LanguageRun(text: 'invoice', language: ReadingLanguage.arabic),
        ),
      );
    });
  });
}
