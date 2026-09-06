import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_available_voices.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

// F11-T07: the «صوت القراءة» picker's own voice list.
void main() {
  test('answers whatever the device reports', () async {
    const voices = [
      TtsVoice(name: 'Maged', locale: 'ar-EG'),
      TtsVoice(name: 'Samantha', locale: 'en-US'),
    ];
    final tts = FakeTextToSpeechService(voices: voices);
    addTearDown(tts.dispose);
    final useCase = GetAvailableVoices(tts);

    expect(await useCase(), const Ok<List<TtsVoice>, AppFailure>(voices));
  });

  test('reports the engine failure rather than swallowing it', () async {
    final tts = FakeTextToSpeechService(getVoicesFails: true);
    addTearDown(tts.dispose);
    final useCase = GetAvailableVoices(tts);

    expect(
      await useCase(),
      const Err<List<TtsVoice>, AppFailure>(TtsFailure()),
    );
  });
}
