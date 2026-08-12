import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';

/// Pauses whatever the reader is speaking, in place, so a later
/// [TextToSpeechService.resume] can continue it (F10-T05).
///
/// A thin forward onto [TextToSpeechService.pause] — kept as its own use case
/// rather than a raw call from the cubit, the same architecture rule
/// `StopReading` follows.
final class PauseReading {
  const PauseReading(this._tts);

  final TextToSpeechService _tts;

  Future<Result<void, AppFailure>> call() => _tts.pause();
}
