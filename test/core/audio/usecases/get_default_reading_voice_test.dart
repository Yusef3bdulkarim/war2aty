import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';

import '../../../support/fakes.dart';

// F11-T07: the default reading voice setting's own read side.
void main() {
  test(
    'defaults to null (الصوت الافتراضي) when the user has never set it',
    () async {
      final useCase = GetDefaultReadingVoice(FakeDefaultReadingVoiceStore());

      expect(await useCase(), isNull);
    },
  );

  test('reflects an explicit choice', () async {
    const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
    final useCase = GetDefaultReadingVoice(FakeDefaultReadingVoiceStore(voice));

    expect(await useCase(), voice);
  });
}
