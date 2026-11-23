import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/voice/voice_playback_state.dart';
import 'package:war2aty/features/paper/presentation/models/paper_voice_progress.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';

const _spans = [
  SpokenCardSpan(
    segmentId: 'explain',
    start: Duration.zero,
    end: Duration(seconds: 10),
    exact: true,
  ),
  SpokenCardSpan(
    segmentId: 'todo',
    start: Duration(seconds: 10),
    end: Duration(seconds: 20),
    exact: true,
  ),
];

void main() {
  group('PaperVoiceProgress', () {
    test('is empty while nothing is playing', () {
      expect(
        PaperVoiceProgress.of(const VoicePlaybackIdle()),
        const PaperVoiceProgress(),
      );
      expect(
        PaperVoiceProgress.of(const VoicePlaybackPreparing()),
        const PaperVoiceProgress(),
      );
    });

    test('is empty once the first reading has finished', () {
      expect(
        PaperVoiceProgress.of(
          VoicePlaybackReadFinished(
            VoiceReadOutcome(
              engine: VoiceEngine.geminiLive,
              duration: const Duration(seconds: 20),
              verified: true,
              audioSaved: true,
              spans: _spans,
            ),
          ),
        ),
        const PaperVoiceProgress(),
      );
    });

    test('has no active card before a position lands in one', () {
      expect(
        PaperVoiceProgress.of(
          const VoicePlaybackStreaming(engine: VoiceEngine.geminiLive),
        ),
        const PaperVoiceProgress(),
      );
    });

    test('fills the active card by how far the voice is through its span', () {
      final progress = PaperVoiceProgress.of(
        const VoicePlaybackStreaming(
          engine: VoiceEngine.geminiLive,
          position: Duration(seconds: 15),
          segmentId: 'todo',
          spans: _spans,
        ),
      );

      expect(progress.activeId, 'todo');
      expect(progress.fillFraction, 0.5);
    });

    test('does the same in the saved reading', () {
      final progress = PaperVoiceProgress.of(
        const VoicePlaybackFile(
          duration: Duration(seconds: 20),
          position: Duration(seconds: 2),
          segmentId: 'explain',
          spans: _spans,
        ),
      );

      expect(progress.activeId, 'explain');
      expect(progress.fillFraction, 0.2);
    });

    test('fills the card completely when the position is past its '
        'span, as in a gap between cards', () {
      final progress = PaperVoiceProgress.of(
        const VoicePlaybackStreaming(
          engine: VoiceEngine.deviceTts,
          position: Duration(seconds: 30),
          segmentId: 'todo',
          spans: _spans,
        ),
      );

      expect(progress.activeId, 'todo');
      expect(progress.fillFraction, 1);
    });

    test('keeps the card with no fill when its span is unknown', () {
      final progress = PaperVoiceProgress.of(
        const VoicePlaybackStreaming(
          engine: VoiceEngine.deviceTts,
          position: Duration(seconds: 3),
          segmentId: 'todo',
        ),
      );

      expect(progress.activeId, 'todo');
      expect(progress.fillFraction, 0);
    });
  });
}
