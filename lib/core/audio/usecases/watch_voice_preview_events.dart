import '../../../features/audio_reader/domain/entities/tts_event.dart';
import '../../../features/audio_reader/domain/services/text_to_speech_service.dart';

/// The engine's own playback events, for the one screen that speaks outside
/// `ReadingQueue` (F31).
///
/// «تجربة الصوت» needs to know when its sample has finished, and nothing
/// else could tell it: `speak` answers as soon as the engine *accepts* the
/// utterance, not when it stops talking (F30-T09), so a row offering to stop
/// the preview would otherwise go on offering it after the sample ended.
///
/// Watches the engine rather than the reading queue's published stream,
/// matching [PreviewDefaultVoice] and [StopVoicePreview] — the preview is
/// not a reading, and the queue's stream is about readings: it rewrites
/// progress offsets into a reading's coordinates and swallows the completion
/// of all but the last run.
final class WatchVoicePreviewEvents {
  const WatchVoicePreviewEvents(this._tts);

  final TextToSpeechService _tts;

  Stream<TtsEvent> call() => _tts.events;
}
