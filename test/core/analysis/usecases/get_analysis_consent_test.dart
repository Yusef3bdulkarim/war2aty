import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';

import '../../../support/fakes.dart';

// F11-T02: the analysis consent setting's own read side.
void main() {
  test('defaults on when the user has never set it', () async {
    final useCase = GetAnalysisConsent(FakeAnalysisConsentStore());

    expect(await useCase(), isTrue);
  });

  test('reflects an explicit true', () async {
    final useCase = GetAnalysisConsent(FakeAnalysisConsentStore(true));

    expect(await useCase(), isTrue);
  });

  test('reflects an explicit false', () async {
    final useCase = GetAnalysisConsent(FakeAnalysisConsentStore(false));

    expect(await useCase(), isFalse);
  });
}
