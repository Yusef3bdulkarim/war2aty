import '../../../features/audio_reader/domain/services/text_to_speech_service.dart';
import '../../error/app_failure.dart';
import '../../result/result.dart';

/// Silences «تجربة الصوت» before it reaches the end (F31).
///
/// The counterpart to [PreviewDefaultVoice], and deliberately its own use
/// case rather than `StopReading`: the preview speaks straight to the engine
/// instead of through `ReadingQueue` (F30-T11), because it previews one
/// specific voice rather than reading a paper. Stopping it belongs on the
/// same side of that line — routing it through the queue would claim the
/// engine from a reading the queue might be sequencing, and clear a queue
/// this screen knows nothing about.
///
/// The cancel the engine reports for the silenced utterance is the one the
/// queue already ignores unless it had told itself a run of its own was
/// speaking, so this cannot advance somebody else's reading.
final class StopVoicePreview {
  const StopVoicePreview(this._tts);

  final TextToSpeechService _tts;

  Future<Result<void, AppFailure>> call() => _tts.stop();
}
