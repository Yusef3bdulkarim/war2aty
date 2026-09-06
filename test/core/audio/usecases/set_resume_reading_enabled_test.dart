import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/usecases/get_resume_reading_enabled.dart';
import 'package:war2aty/core/audio/usecases/set_resume_reading_enabled.dart';

import '../../../support/fakes.dart';

// F11-T07: the resume-reading setting's own write side.
void main() {
  test('persists the choice so a later read reflects it', () async {
    final store = FakeResumeReadingEnabledStore();
    final setEnabled = SetResumeReadingEnabled(store);
    final getEnabled = GetResumeReadingEnabled(store);

    await setEnabled(false);

    expect(await getEnabled(), isFalse);
  });

  test('turning it back on overwrites the previous off', () async {
    final store = FakeResumeReadingEnabledStore(false);
    final setEnabled = SetResumeReadingEnabled(store);
    final getEnabled = GetResumeReadingEnabled(store);

    await setEnabled(true);

    expect(await getEnabled(), isTrue);
  });
}
