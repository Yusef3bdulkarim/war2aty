import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';

VoiceReadOutcome _outcome({
  VoiceEngine engine = VoiceEngine.geminiLive,
  Duration duration = const Duration(seconds: 10),
  bool verified = true,
  bool audioSaved = true,
  List<SpokenCardSpan> spans = const [],
}) => VoiceReadOutcome(
  engine: engine,
  duration: duration,
  verified: verified,
  audioSaved: audioSaved,
  spans: spans,
);

void main() {
  group('two outcomes agreeing on everything', () {
    test('are the same value', () {
      expect(_outcome(), _outcome());
      expect(_outcome().hashCode, _outcome().hashCode);
    });

    test('agree even when their span lists came from different instances', () {
      const span = SpokenCardSpan(
        segmentId: 'explain',
        start: Duration.zero,
        end: Duration(seconds: 5),
        exact: true,
      );

      expect(_outcome(spans: [span]), _outcome(spans: [span]));
      expect(
        _outcome(spans: [span]).hashCode,
        _outcome(spans: [span]).hashCode,
      );
    });
  });

  group('an outcome differing on one field', () {
    test('a different engine is a different value', () {
      expect(_outcome(engine: VoiceEngine.deviceTts), isNot(_outcome()));
    });

    test('a different verified flag is a different value', () {
      expect(_outcome(verified: false), isNot(_outcome()));
    });

    test('a different audioSaved flag is a different value', () {
      expect(_outcome(audioSaved: false), isNot(_outcome()));
    });

    test('a different span list is a different value', () {
      const span = SpokenCardSpan(
        segmentId: 'explain',
        start: Duration.zero,
        end: Duration(seconds: 5),
        exact: true,
      );

      expect(_outcome(spans: [span]), isNot(_outcome()));
    });
  });
}
