import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakeTextToSpeechService tts;
  late StopReading useCase;

  setUp(() {
    tts = FakeTextToSpeechService();
    useCase = StopReading(tts);
  });

  tearDown(() => tts.dispose());

  group('StopReading', () {
    test('stops the engine', () async {
      final outcome = await useCase();

      expect(outcome, const Ok<void, AppFailure>(null));
      expect(tts.stopCount, 1);
    });

    test('reports the engine failure rather than swallowing it', () async {
      tts.stopFails = true;

      final outcome = await useCase();

      expect(outcome, const Err<void, AppFailure>(TtsFailure()));
    });
  });
}
