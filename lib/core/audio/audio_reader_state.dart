import '../../features/audio_reader/domain/entities/reading_speed.dart';
import '../documents/reading_mode.dart';
import '../error/app_failure.dart';

/// States of the result screen's audio reader mini-player (F10).
sealed class AudioReaderState {
  const AudioReaderState();
}

/// Nothing is being read; the mini-player is hidden.
final class AudioReaderIdle extends AudioReaderState {
  const AudioReaderIdle();
}

/// [mode] is currently being read aloud, or sits paused mid-way through if
/// [isPaused] (F10-T05) — either way the mini-player stays on screen; only
/// [AudioReaderIdle]/[stop] hides it. [speed] (F10-T06) is whatever the
/// options sheet was last confirmed with — [ReadingSpeed.normal] for a
/// reading nothing has changed it away from yet. [progress] (F10-T08) is how
/// far through the reading the engine has reached, 0 to 1 — `0` for a
/// reading nothing has reported progress on yet, whether that is a fresh
/// start or one still paused before its first `TtsProgressed` event.
final class AudioReaderReading extends AudioReaderState {
  const AudioReaderReading(
    this.mode, {
    this.isPaused = false,
    this.speed = ReadingSpeed.normal,
    this.progress = 0,
  });

  final ReadingMode mode;
  final bool isPaused;
  final ReadingSpeed speed;
  final double progress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioReaderReading &&
          other.mode == mode &&
          other.isPaused == isPaused &&
          other.speed == speed &&
          other.progress == progress;

  @override
  int get hashCode => Object.hash(mode, isPaused, speed, progress);
}

/// The engine could not start (or stop) speaking. Carries the failure rather
/// than a message so the screen picks the Arabic copy (CLAUDE.md §B5); this
/// is reported once by a listener rather than drawn as the mini-player's own
/// state — the same shape `SaveDocumentFailed` uses for the same reason.
final class AudioReaderFailed extends AudioReaderState {
  const AudioReaderFailed(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioReaderFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
