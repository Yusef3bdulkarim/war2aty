import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakeTextToSpeechService tts;
  late SetReadingSpeed useCase;

  setUp(() {
    tts = FakeTextToSpeechService();
    useCase = SetReadingSpeed(tts);
  });

  tearDown(() => tts.dispose());

  group('SetReadingSpeed', () {
    test("hands the engine the speed's own rate, not its label", () async {
      final outcome = await useCase(ReadingSpeed.faster);

      expect(outcome, const Ok<void, AppFailure>(null));
      expect(tts.speechRates, [ReadingSpeed.faster.rate]);
    });

    test('reports the engine failure rather than swallowing it', () async {
      tts.setSpeechRateFails = true;

      final outcome = await useCase(ReadingSpeed.normal);

      expect(outcome, const Err<void, AppFailure>(TtsFailure()));
    });
  });
}
