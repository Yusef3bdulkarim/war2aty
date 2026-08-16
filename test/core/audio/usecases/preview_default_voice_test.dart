import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/preview_default_voice.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';

import '../../../support/fakes.dart';

// F11-T07: «تجربة الصوت».
void main() {
  late FakeTextToSpeechService tts;
  late PreviewDefaultVoice useCase;

  setUp(() {
    tts = FakeTextToSpeechService();
    useCase = PreviewDefaultVoice(tts, const SelectVoiceForReading());
  });

  tearDown(() => tts.dispose());

  const sample = 'أهلًا بيك في تطبيق ورقتي بتقول إيه.';

  test('speaks the sample text at the given speed', () async {
    final outcome = await useCase(
      sampleText: sample,
      speed: ReadingSpeed.faster,
    );

    expect(outcome, const Ok<void, AppFailure>(null));
    expect(tts.speechRates, [ReadingSpeed.faster.rate]);
    expect(tts.spoken, [sample]);
  });

  test('applies an explicit voice rather than the automatic match', () async {
    const arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
    const englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');
    tts.voices = [arabicVoice, englishVoice];

    await useCase(
      sampleText: sample,
      speed: ReadingSpeed.normal,
      voice: englishVoice,
    );

    expect(tts.voicesSet, [englishVoice]);
  });

  test(
    'falls back to the automatic script match with no voice given',
    () async {
      const arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
      const englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');
      tts.voices = [englishVoice, arabicVoice];

      await useCase(sampleText: sample, speed: ReadingSpeed.normal);

      expect(tts.voicesSet, [arabicVoice]);
    },
  );

  test('reports a failed rate change rather than speaking anyway', () async {
    tts.setSpeechRateFails = true;

    final outcome = await useCase(
      sampleText: sample,
      speed: ReadingSpeed.normal,
    );

    expect(outcome, const Err<void, AppFailure>(TtsFailure()));
    expect(tts.spoken, isEmpty);
  });

  test('reports the engine failure to speak', () async {
    tts.speakFails = true;

    final outcome = await useCase(
      sampleText: sample,
      speed: ReadingSpeed.normal,
    );

    expect(outcome, const Err<void, AppFailure>(TtsFailure()));
  });
}
