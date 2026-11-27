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
}
