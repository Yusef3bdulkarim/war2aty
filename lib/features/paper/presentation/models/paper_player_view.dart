import '../../../../core/voice/voice_playback_state.dart';

enum PaperPlayerAction { pause, resume, replay }

final class PaperPlayerView {
  const PaperPlayerView({
    required this.action,
    required this.enabled,
    this.preparing = false,
    this.fill,
    this.animated = false,
    this.canSeek = false,
    this.elapsed = Duration.zero,
    this.duration = Duration.zero,
  });

  factory PaperPlayerView.of(VoicePlaybackState state) => switch (state) {
    VoicePlaybackIdle() || VoicePlaybackFailed() => const PaperPlayerView(
      action: PaperPlayerAction.resume,
      enabled: false,
      fill: 0,
    ),
    VoicePlaybackPreparing() => const PaperPlayerView(
      action: PaperPlayerAction.resume,
      enabled: false,
      preparing: true,
      fill: 0,
    ),
    VoicePlaybackStreaming(:final isPaused, :final position) => PaperPlayerView(
      action: isPaused ? PaperPlayerAction.resume : PaperPlayerAction.pause,
      enabled: state.canPause,
      animated: !isPaused,
      elapsed: position,
    ),
    VoicePlaybackFile(:final duration, :final position, :final isPaused) =>
      PaperPlayerView(
        action: isPaused ? PaperPlayerAction.resume : PaperPlayerAction.pause,
        enabled: true,
        fill: duration > Duration.zero
            ? (position.inMicroseconds / duration.inMicroseconds).clamp(
                0.0,
                1.0,
              )
            : 0,
        canSeek: duration > Duration.zero,
        elapsed: position,
        duration: duration,
      ),
    VoicePlaybackReadFinished(:final outcome, :final canReplay) =>
      PaperPlayerView(
        action: PaperPlayerAction.replay,
        enabled: canReplay,
        fill: 1,
        elapsed: outcome.duration,
      ),
  };

  final PaperPlayerAction action;
  final bool enabled;
  final bool preparing;

  final double? fill;

  final bool animated;
  final bool canSeek;
  final Duration elapsed;
  final Duration duration;

  String get clock {
    final minutes = elapsed.inMinutes;
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  bool operator ==(Object other) =>
      other is PaperPlayerView &&
      other.action == action &&
      other.enabled == enabled &&
      other.preparing == preparing &&
      other.fill == fill &&
      other.animated == animated &&
      other.canSeek == canSeek &&
      other.elapsed.inSeconds == elapsed.inSeconds &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(
    action,
    enabled,
    preparing,
    fill,
    animated,
    canSeek,
    elapsed.inSeconds,
    duration,
  );

  @override
  String toString() =>
      'PaperPlayerView($action, enabled: $enabled, preparing: $preparing, '
      'fill: $fill, animated: $animated, canSeek: $canSeek, $clock)';
}
