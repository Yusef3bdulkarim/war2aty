import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';

/// Stops whatever the reader is speaking (F10-T04).
///
/// A thin forward onto [TextToSpeechService.stop] — kept as its own use case
/// rather than a raw call from the cubit, the same architecture rule
/// `StartReading` follows. Also used to silence the engine when the reading
/// cubit is torn down, so leaving the result page never leaves the device
/// talking on its own.
final class StopReading {
  const StopReading(this._tts);

  final TextToSpeechService _tts;

  Future<Result<void, AppFailure>> call() => _tts.stop();
}
