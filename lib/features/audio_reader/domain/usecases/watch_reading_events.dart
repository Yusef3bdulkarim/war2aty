import '../entities/tts_event.dart';
import '../services/text_to_speech_service.dart';

/// The reader's playback lifecycle, one [TtsEvent] per state change (F10-T08).
///
/// A thin forward onto [TextToSpeechService.events] — kept as its own use
/// case rather than a raw stream read from the cubit, the same architecture
/// rule `PauseReading` and its siblings follow.
final class WatchReadingEvents {
  const WatchReadingEvents(this._tts);

  final TextToSpeechService _tts;

  Stream<TtsEvent> call() => _tts.events;
}
