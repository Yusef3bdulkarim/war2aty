/// A playback lifecycle event emitted by `TextToSpeechService.events`.
///
/// Mirrors the handlers `flutter_tts` reports natively (start / progress /
/// pause / continue / complete / cancel / error) as a closed union, so a
/// later consumer (F10-T08's progress tracking) can `switch` on it
/// exhaustively instead of juggling nullable callbacks.
sealed class TtsEvent {
  const TtsEvent();
}

/// Speaking began.
final class TtsStarted extends TtsEvent {
  const TtsStarted();
}

/// Reached the given word boundary within the text currently being spoken.
///
/// [start] and [end] are UTF-16 code unit offsets into that text — the same
/// indices `String.substring` expects — not offsets into a longer document
/// the reading-text builder (F10-T02) may have assembled from several parts.
final class TtsProgressed extends TtsEvent {
  const TtsProgressed({required this.start, required this.end});

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is TtsProgressed && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Speaking was paused and can be resumed from where it left off.
final class TtsPaused extends TtsEvent {
  const TtsPaused();
}

/// Speaking resumed after a pause.
final class TtsContinued extends TtsEvent {
  const TtsContinued();
}

/// Speaking reached the end of the text on its own.
final class TtsCompleted extends TtsEvent {
  const TtsCompleted();
}

/// Speaking was stopped before it reached the end.
final class TtsCancelled extends TtsEvent {
  const TtsCancelled();
}

/// The engine reported an error mid-utterance.
final class TtsFailed extends TtsEvent {
  const TtsFailed();
}
