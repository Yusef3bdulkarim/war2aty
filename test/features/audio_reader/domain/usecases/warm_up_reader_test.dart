import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/warm_up_reader.dart';

import '../../../../support/fakes.dart';

/// F30-T06. The two slow things about starting a reading — the OS engine
/// binding its service, and `getVoices` enumerating every voice of every
/// installed engine — both used to land on the tap. This moves them off it.
void main() {
  late FakeTextToSpeechService tts;
  late WarmUpReader warmUp;

  setUp(() {
    tts = FakeTextToSpeechService();
    warmUp = WarmUpReader(tts);
  });

  tearDown(() => tts.dispose());

  test(
    'asks the engine for its voices, which is what fills the cache',
    () async {
      await warmUp();

      expect(tts.getVoicesCount, 1);
    },
  );

  test('speaks nothing — a warm-up is silent', () async {
    tts.voices = const [TtsVoice(name: 'ar-EG-local', locale: 'ar-EG')];

    await warmUp();

    // Priming the engine must not make a sound, or the result screen would
    // start talking the moment it opened.
    expect(tts.spoken, isEmpty);
    expect(tts.voicesSet, isEmpty);
  });

  test('a failing engine is not reported anywhere', () async {
    tts.getVoicesFails = true;

    // Nothing to catch and nothing to surface: the reading will ask again,
    // so a failed warm-up has cost the user nothing.
    await expectLater(warmUp(), completes);
  });

  test(
    'an engine still binding answers with nothing, and that is fine',
    () async {
      // Android reports no voices at all until its engine finishes binding.
      tts.voices = const [];

      await expectLater(warmUp(), completes);
      expect(tts.getVoicesCount, 1);
    },
  );
}
