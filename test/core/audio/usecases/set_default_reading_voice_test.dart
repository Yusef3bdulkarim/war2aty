import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_voice.dart';

import '../../../support/fakes.dart';

// F11-T07: the default reading voice setting's own write side.
void main() {
  test('persists the choice so a later read reflects it', () async {
    const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
    final store = FakeDefaultReadingVoiceStore();
    final setVoice = SetDefaultReadingVoice(store);
    final getVoice = GetDefaultReadingVoice(store);

    await setVoice(voice);

    expect(await getVoice(), voice);
  });

  test('picking «الصوت الافتراضي» again resets it back to null', () async {
    const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
    final store = FakeDefaultReadingVoiceStore(voice);
    final setVoice = SetDefaultReadingVoice(store);
    final getVoice = GetDefaultReadingVoice(store);

    await setVoice(null);

    expect(await getVoice(), isNull);
  });
}
