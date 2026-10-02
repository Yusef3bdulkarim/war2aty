import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';

/// The failure pages' counted strings and their truthfulness rules (F23).
void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('analysisLimitResetsIn', () {
    test('Arabic counts hours: one, two, few, many', () {
      expect(ar.analysisLimitResetsIn(1, 0), 'ساعة');
      expect(ar.analysisLimitResetsIn(2, 0), 'ساعتين');
      expect(ar.analysisLimitResetsIn(5, 0), '5 ساعات');
      expect(ar.analysisLimitResetsIn(10, 0), '10 ساعات');
      expect(ar.analysisLimitResetsIn(11, 0), '11 ساعة');
      expect(ar.analysisLimitResetsIn(23, 0), '23 ساعة');
    });

    test('Arabic counts minutes: one, two, few, many', () {
      expect(ar.analysisLimitResetsIn(0, 1), 'دقيقة');
      expect(ar.analysisLimitResetsIn(0, 2), 'دقيقتين');
      expect(ar.analysisLimitResetsIn(0, 7), '7 دقايق');
      expect(ar.analysisLimitResetsIn(0, 45), '45 دقيقة');
    });

    test('joins hours and minutes as the mockup does', () {
      expect(ar.analysisLimitResetsIn(5, 12), '5 ساعات و 12 دقيقة');
      expect(en.analysisLimitResetsIn(5, 12), '5 hours and 12 minutes');
      expect(en.analysisLimitResetsIn(1, 1), '1 hour and 1 minute');
    });
  });

  group('analysisLimitReachedMessageWithLimit', () {
    test('Arabic names the limit with its plural', () {
      expect(
        ar.analysisLimitReachedMessageWithLimit(1),
        startsWith('عندك تحليل ذكي واحد كل يوم'),
      );
      expect(
        ar.analysisLimitReachedMessageWithLimit(2),
        startsWith('عندك تحليلين ذكيين كل يوم'),
      );
      expect(
        ar.analysisLimitReachedMessageWithLimit(3),
        startsWith('عندك 3 تحليلات ذكية كل يوم، واستخدمتهم كلهم.'),
      );
      expect(
        ar.analysisLimitReachedMessageWithLimit(12),
        startsWith('عندك 12 تحليل ذكي كل يوم'),
      );
    });

    test('always ends by saying the text is still there', () {
      for (final limit in [1, 2, 3, 12]) {
        expect(
          ar.analysisLimitReachedMessageWithLimit(limit),
          endsWith('الكلام اللي في الورقة لسه متاح تقراه دلوقتي.'),
        );
      }
      expect(
        ar.analysisLimitReachedMessage,
        endsWith('الكلام اللي في الورقة لسه متاح تقراه دلوقتي.'),
      );
    });

    test('English uses the singular for one', () {
      expect(
        en.analysisLimitReachedMessageWithLimit(1),
        startsWith('You get 1 smart analysis a day'),
      );
      expect(
        en.analysisLimitReachedMessageWithLimit(3),
        startsWith('You get 3 smart analyses a day'),
      );
    });
  });

  test('the usage pill names the limit twice', () {
    expect(ar.analysisLimitUsedOf(3), 'استخدمت 3 من 3 النهارده');
    expect(en.analysisLimitUsedOf(3), 'Used 3 of 3 today');
  });

  test('the tracker reads as one sentence', () {
    expect(
      ar.analysisStepsSemantics(ar.analysisStepWaitingForInternet),
      'الصورة تمام، وقراية الكلام تمام، والشرح مستني النت',
    );
  });

  group('truthfulness (F23 #6, #8)', () {
    test('the no-internet copy never says where the text was read', () {
      // The online reading may have succeeded before the connection fell.
      expect(ar.analysisNoInternetMessage, isNot(contains('موبايلك')));
      expect(
        en.analysisNoInternetMessage.toLowerCase(),
        isNot(contains('phone')),
      );
    });

    test('only the unsupported page says the attempt did not count', () {
      // A dropped socket or a client timeout may still have been counted.
      for (final text in [
        ar.analysisNoInternetMessage,
        ar.analysisFailedMessage,
      ]) {
        expect(text, isNot(contains('متحسبتش')));
      }
      expect(ar.analysisAttemptNotCounted, contains('متحسبتش'));
    });

    test('the limit page no longer offers listening', () {
      expect(ar.analysisLimitReachedMessage, isNot(contains('تسمع')));
      expect(
        ar.analysisLimitReachedMessageWithLimit(3),
        isNot(contains('تسمع')),
      );
    });
  });
}
