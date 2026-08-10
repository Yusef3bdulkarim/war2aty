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

/// [mode] is currently being read aloud.
final class AudioReaderReading extends AudioReaderState {
  const AudioReaderReading(this.mode);

  final ReadingMode mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioReaderReading && other.mode == mode;

  @override
  int get hashCode => mode.hashCode;
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
