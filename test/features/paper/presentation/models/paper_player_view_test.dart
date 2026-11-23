import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/voice/voice_playback_state.dart';
import 'package:war2aty/features/paper/presentation/models/paper_player_view.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';

VoiceReadOutcome _outcome({required bool audioSaved}) => VoiceReadOutcome(
  engine: audioSaved ? VoiceEngine.geminiLive : VoiceEngine.deviceTts,
  duration: const Duration(seconds: 75),
  verified: true,
  audioSaved: audioSaved,
  spans: const [],
);

void main() {
  group('PaperPlayerView', () {
    test('idle offers a disabled play with an empty waveform', () {
      final view = PaperPlayerView.of(const VoicePlaybackIdle());

      expect(view.action, PaperPlayerAction.resume);
      expect(view.enabled, isFalse);
      expect(view.preparing, isFalse);
      expect(view.fill, 0);
      expect(view.animated, isFalse);
      expect(view.clock, '0:00');
    });

    test('preparing is a disabled play marked as preparing', () {
      final view = PaperPlayerView.of(const VoicePlaybackPreparing());

      expect(view.preparing, isTrue);
      expect(view.enabled, isFalse);
      expect(view.animated, isFalse);
    });

    test('streaming on Live offers pause, animates and never fills', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackStreaming(
          engine: VoiceEngine.geminiLive,
          position: Duration(seconds: 42),
        ),
      );

      expect(view.action, PaperPlayerAction.pause);
      expect(view.enabled, isTrue);
      expect(view.animated, isTrue);
      expect(view.fill, isNull);
      expect(view.canSeek, isFalse);
      expect(view.clock, '0:42');
    });

    test('streaming on the device tier cannot be paused', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackStreaming(engine: VoiceEngine.deviceTts),
      );

      expect(view.action, PaperPlayerAction.pause);
      expect(view.enabled, isFalse);
      expect(view.animated, isTrue);
      expect(view.canSeek, isFalse);
    });

    test('a paused stream offers resume and stops animating', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackStreaming(
          engine: VoiceEngine.geminiLive,
          isPaused: true,
        ),
      );

      expect(view.action, PaperPlayerAction.resume);
      expect(view.enabled, isTrue);
      expect(view.animated, isFalse);
      expect(view.fill, isNull);
    });

    test('the file phase fills by position over duration and can seek', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackFile(
          duration: Duration(seconds: 80),
          position: Duration(seconds: 20),
        ),
      );

      expect(view.action, PaperPlayerAction.pause);
      expect(view.enabled, isTrue);
      expect(view.fill, 0.25);
      expect(view.canSeek, isTrue);
      expect(view.animated, isFalse);
      expect(view.duration, const Duration(seconds: 80));
      expect(view.clock, '0:20');
    });

    test('a paused file offers resume', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackFile(
          duration: Duration(seconds: 80),
          isPaused: true,
        ),
      );

      expect(view.action, PaperPlayerAction.resume);
      expect(view.enabled, isTrue);
    });

    test('a finished file is full and offers resume', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackFile(
          duration: Duration(seconds: 80),
          position: Duration(seconds: 80),
          isPaused: true,
        ),
      );

      expect(view.fill, 1);
      expect(view.action, PaperPlayerAction.resume);
    });

    test('a file of unknown length cannot seek and stays empty', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackFile(
          duration: Duration.zero,
          position: Duration(seconds: 5),
        ),
      );

      expect(view.fill, 0);
      expect(view.canSeek, isFalse);
    });

    test('a position past the end never overfills', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackFile(
          duration: Duration(seconds: 10),
          position: Duration(seconds: 12),
        ),
      );

      expect(view.fill, 1);
    });

    test('a finished read with a saved file offers replay, full', () {
      final view = PaperPlayerView.of(
        VoicePlaybackReadFinished(_outcome(audioSaved: true)),
      );

      expect(view.action, PaperPlayerAction.replay);
      expect(view.enabled, isTrue);
      expect(view.fill, 1);
      expect(view.clock, '1:15');
    });

    test('a finished read with no file cannot be replayed', () {
      final view = PaperPlayerView.of(
        VoicePlaybackReadFinished(_outcome(audioSaved: false)),
      );

      expect(view.action, PaperPlayerAction.replay);
      expect(view.enabled, isFalse);
    });

    test('failed is a disabled play with an empty waveform', () {
      final view = PaperPlayerView.of(
        const VoicePlaybackFailed(AudioPlaybackFailure()),
      );

      expect(view.enabled, isFalse);
      expect(view.fill, 0);
      expect(view.animated, isFalse);
    });

    test('the clock pads seconds and counts minutes', () {
      expect(
        PaperPlayerView.of(
          const VoicePlaybackStreaming(
            engine: VoiceEngine.geminiLive,
            position: Duration(minutes: 2, seconds: 5),
          ),
        ).clock,
        '2:05',
      );
    });
  });
}
