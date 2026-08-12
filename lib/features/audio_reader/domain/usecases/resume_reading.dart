import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';

/// Resumes a reading previously paused, continuing from where it left off
/// (F10-T05).
///
/// A thin forward onto [TextToSpeechService.resume] — kept as its own use
/// case rather than a raw call from the cubit, the same architecture rule
/// `StopReading` follows.
final class ResumeReading {
  const ResumeReading(this._tts);

  final TextToSpeechService _tts;

  Future<Result<void, AppFailure>> call() => _tts.resume();
}
