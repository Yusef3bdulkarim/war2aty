import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/usecases/normalise_arabic_for_diff.dart';
import 'package:war2aty/features/voice/domain/usecases/verify_verbatim_read.dart';

/// F37-T05 · the Dart side of the spike's verbatim judgement.
///
/// The first eleven groups are `supabase/tests/unit/live-spike-diff.test.ts`
/// ported case for case, with the same inputs and the same expectations. They
/// are duplicated rather than shared on purpose: the Deno tool decided whether
/// F37 could be built, the Dart code makes the same call on every read a user
/// hears, and the only way to know the two still agree is to assert the same
/// facts about both. A case that passes there and fails here means the gate has
/// stopped describing the product.
void main() {
  const normalise = NormaliseArabicForDiff();
  const verify = VerifyVerbatimRead(normalise);

  const sentence = 'الاجتماع يوم 20 نوفمبر الساعة 10 الصبح.';

  // ── folding (ported) ─────────────────────────────────────────────────────

  group('folding', () {
    test('drops diacritics and tatweel', () {
      expect(normalise('لازم تبلّغ المدرســة'), normalise('لازم تبلغ المدرسه'));
    });

    test('folds the alef family, ya and ta marbuta', () {
      expect(normalise('أولياء الأمور'), normalise('اولياء الامور'));
      expect(normalise('على مدرسة'), normalise('علي مدرسه'));
    });

    test('folds Arabic-Indic digits to ASCII', () {
      expect(normalise('٢٠ نوفمبر'), '20 نوفمبر');
      expect(normalise('۱۰ الصبح'), '10 الصبح');
    });

    test('strips punctuation and collapses whitespace', () {
      expect(normalise('  روح الاجتماع،   بنفسك!  '), 'روح الاجتماع بنفسك');
    });

    test('empty text yields no words, not one empty word', () {
      expect(normalise.wordsOf('   '), isEmpty);
      expect(normalise.wordsOf('؟!'), isEmpty);
    });
  });

  // ── the verdict (ported) ─────────────────────────────────────────────────

  group('the verdict', () {
    test('an identical read is 0% WER', () {
      final diff = verify(source: sentence, heard: sentence);

      expect(diff.wordErrorRate, 0);
      expect(diff.dropped, isEmpty);
      expect(diff.added, isEmpty);
      expect(diff.verdict, VerbatimVerdict.verbatim);
    });

    test('a read that differs only by spelling is 0% WER', () {
      const heard = 'الإجتماع يوم ٢٠ نوفمبر الساعه ١٠ الصبح';

      expect(verify(source: sentence, heard: heard).wordErrorRate, 0);
    });

    test(
      'an added greeting is listed, and stays under the 5% gate on a page',
      () {
        final source = [sentence, sentence, sentence].join(' ');
        final heard = ['أهلاً بيك', sentence, sentence, sentence].join(' ');

        final diff = verify(source: source, heard: heard);

        expect(diff.added, ['اهلا', 'بيك']);
        expect(diff.dropped, isEmpty);
        expect(
          diff.wordErrorRate,
          closeTo(2 / normalise.wordsOf(source).length, 1e-9),
        );
      },
    );

    test('a greeting costs a short paper more than a long one', () {
      // Worth pinning, because the Deno case above is named for the 5 % gate
      // but its own three sentences are only 21 words — where two added words
      // are 9.5 %, i.e. NEAR-verbatim, not verbatim. The rate is a fraction of
      // the page, so the shorter the paper the harsher the gate.
      //
      // This is why the near band is tolerated rather than retried: a real
      // page is ~850 characters (§33.3), where the same greeting is ~1.5 %, and
      // failing a one-sentence paper over a politeness token would mean
      // reading the shortest papers twice for nothing.
      const greeting = 'أهلاً بيك';

      final shortPaper = [sentence, sentence, sentence].join(' ');
      final realPage = List.filled(19, sentence).join(' ');

      expect(
        verify(source: shortPaper, heard: '$greeting $shortPaper').verdict,
        VerbatimVerdict.nearVerbatim,
      );
      expect(
        verify(source: realPage, heard: '$greeting $realPage').verdict,
        VerbatimVerdict.verbatim,
      );
    });

    test('a dropped number is listed as dropped', () {
      const heard = 'الاجتماع يوم نوفمبر الساعة 10 الصبح';

      final diff = verify(source: sentence, heard: heard);

      expect(diff.dropped, ['20']);
      expect(diff.added, isEmpty);
    });

    test('a paraphrase lands far above the 15% gate', () {
      const heard = 'المدرسة عاملة اجتماع لأولياء الأمور الشهر الجاي الصبح';

      final diff = verify(source: sentence, heard: heard);

      expect(diff.wordErrorRate, greaterThan(0.15));
      expect(diff.verdict, VerbatimVerdict.notVerbatim);
      expect(diff.isAcceptable, isFalse);
    });

    test('nothing heard at all is 100% WER, never a division by zero', () {
      expect(verify(source: sentence, heard: '').wordErrorRate, 1);
      expect(verify(source: '', heard: '').wordErrorRate, 1);
    });
  });

  // ── the bands ────────────────────────────────────────────────────────────

  group('the three bands are the spike\'s own', () {
    test('5% and 15% are the boundaries, inclusive at each', () {
      expect(VerifyVerbatimRead.maxVerbatimWordErrorRate, 0.05);
      expect(VerifyVerbatimRead.maxNearVerbatimWordErrorRate, 0.15);

      expect(
        VerbatimComparison(wordErrorRate: 0.05, dropped: [], added: []).verdict,
        VerbatimVerdict.verbatim,
      );
      expect(
        VerbatimComparison(
          wordErrorRate: 0.0501,
          dropped: [],
          added: [],
        ).verdict,
        VerbatimVerdict.nearVerbatim,
      );
      expect(
        VerbatimComparison(wordErrorRate: 0.15, dropped: [], added: []).verdict,
        VerbatimVerdict.nearVerbatim,
      );
      expect(
        VerbatimComparison(
          wordErrorRate: 0.1501,
          dropped: [],
          added: [],
        ).verdict,
        VerbatimVerdict.notVerbatim,
      );
    });

    test(
      'near-verbatim is still acceptable — the words decide, not the rate',
      () {
        expect(
          VerbatimComparison(
            wordErrorRate: 0.1,
            dropped: [],
            added: [],
          ).isAcceptable,
          isTrue,
        );
      },
    );
  });

  // ── judging a read that is still arriving ────────────────────────────────

  group('the early check', () {
    // A page long enough to judge a prefix of.
    final page = List.filled(6, sentence).join(' ');

    test('holds its verdict until enough has been heard', () {
      expect(verify.checkPrefix(source: page, heard: 'الاجتماع يوم'), isNull);
      expect(
        verify.checkPrefix(source: page, heard: sentence),
        isNull,
        reason: 'one sentence is 7 words, under the 20-word floor',
      );
    });

    test('passes a read that is tracking the page', () {
      final heard = [sentence, sentence, sentence, sentence].join(' ');

      final diff = verify.checkPrefix(source: page, heard: heard);

      expect(diff, isNotNull);
      expect(diff!.verdict, VerbatimVerdict.verbatim);
    });

    test('catches a paraphrase before the whole paper has been spoken', () {
      // The point of the early check: this is caught at the third second
      // rather than the fortieth.
      final heard = List.filled(
        4,
        'المدرسة عاملة اجتماع لأولياء الأمور الشهر الجاي الصبح',
      ).join(' ');

      final diff = verify.checkPrefix(source: page, heard: heard);

      expect(diff, isNotNull);
      expect(diff!.verdict, VerbatimVerdict.notVerbatim);
    });

    test('tolerates a delta that landed mid-word', () {
      // The newest word is dropped before comparing, so a partial token does
      // not read as one dropped plus one added word.
      final heard = '${[sentence, sentence, sentence].join(' ')} الاجتم';

      final diff = verify.checkPrefix(source: page, heard: heard);

      expect(diff, isNotNull);
      expect(diff!.verdict, VerbatimVerdict.verbatim);
    });

    test('compares the whole page once more has been heard than it holds', () {
      final heard = List.filled(8, sentence).join(' ');

      final diff = verify.checkPrefix(source: page, heard: heard);

      expect(diff, isNotNull);
      expect(
        diff!.added,
        isNotEmpty,
        reason: 'the extra sentences are words the page does not have',
      );
    });
  });

  group('a comparison does not carry the paper into a log', () {
    test('describes itself by counts, never by the words', () {
      const heard = 'الاجتماع يوم نوفمبر الساعة 10 الصبح';

      final text = verify(source: sentence, heard: heard).toString();

      expect(text, contains('1 dropped'));
      expect(text, isNot(contains('20')));
      expect(text, isNot(contains('نوفمبر')));
    });
  });
}
