import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/set_analysis_consent.dart';

import '../../../support/fakes.dart';

// F11-T02: the analysis consent setting's own write side.
void main() {
  test('persists the choice so a later read reflects it', () async {
    final store = FakeAnalysisConsentStore();
    final setConsent = SetAnalysisConsent(store);
    final getConsent = GetAnalysisConsent(store);

    await setConsent(false);

    expect(await getConsent(), isFalse);
  });

  test('turning it back on overwrites a prior decline', () async {
    final store = FakeAnalysisConsentStore(false);
    final setConsent = SetAnalysisConsent(store);
    final getConsent = GetAnalysisConsent(store);

    await setConsent(true);

    expect(await getConsent(), isTrue);
  });
}
