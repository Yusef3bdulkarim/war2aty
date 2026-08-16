import '../../../../core/audio/reading_speed.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';

/// Applies a [ReadingSpeed] to the engine, ahead of the utterance it should
/// govern (F10-T06).
///
/// A thin forward onto [TextToSpeechService.setSpeechRate] — kept as its own
/// use case rather than a raw call from the cubit, the same architecture rule
/// `PauseReading` follows.
final class SetReadingSpeed {
  const SetReadingSpeed(this._tts);

  final TextToSpeechService _tts;

  Future<Result<void, AppFailure>> call(ReadingSpeed speed) =>
      _tts.setSpeechRate(speed.rate);
}
