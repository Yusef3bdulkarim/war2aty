import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/usecases/get_resume_reading_enabled.dart';

import '../../../support/fakes.dart';

// F11-T07: the resume-reading setting's own read side.
void main() {
  test('defaults to true when the user has never set it', () async {
    final useCase = GetResumeReadingEnabled(FakeResumeReadingEnabledStore());

    expect(await useCase(), isTrue);
  });

  test('reflects an explicit off', () async {
    final useCase = GetResumeReadingEnabled(
      FakeResumeReadingEnabledStore(false),
    );

    expect(await useCase(), isFalse);
  });

  test('reflects an explicit on', () async {
    final useCase = GetResumeReadingEnabled(
      FakeResumeReadingEnabledStore(true),
    );

    expect(await useCase(), isTrue);
  });
}
