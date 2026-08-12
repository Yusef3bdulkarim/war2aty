import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_event.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakeTextToSpeechService tts;
  late WatchReadingEvents useCase;

  setUp(() {
    tts = FakeTextToSpeechService();
    useCase = WatchReadingEvents(tts);
  });

  tearDown(() => tts.dispose());

  group('WatchReadingEvents', () {
    test('forwards whatever the engine reports, in order', () async {
      final events = <TtsEvent>[];
      final subscription = useCase().listen(events.add);
      addTearDown(subscription.cancel);

      tts.emitEvent(const TtsStarted());
      tts.emitEvent(const TtsProgressed(start: 0, end: 5));
      tts.emitEvent(const TtsCompleted());
      await Future<void>.delayed(Duration.zero);

      expect(events, const [
        TtsStarted(),
        TtsProgressed(start: 0, end: 5),
        TtsCompleted(),
      ]);
    });
  });
}
