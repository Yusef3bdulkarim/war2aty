import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';
import 'build_reading_text.dart';

/// Starts reading one [ReadingMode] of a result aloud (F10-T04).
///
/// Combines [BuildReadingText] — which turns the mode into the text — with
/// [TextToSpeechService.speak], so the mini-player's cubit depends on one use
/// case rather than a builder and a service directly (architecture rule:
/// cubits depend on use cases only).
final class StartReading {
  const StartReading(this._buildReadingText, this._tts);

  final BuildReadingText _buildReadingText;
  final TextToSpeechService _tts;

  Future<Result<void, AppFailure>> call({
    required AnalysisResult result,
    required ReadingMode mode,
    required AppStrings strings,
  }) {
    final text = _buildReadingText(
      result: result,
      mode: mode,
      strings: strings,
    );
    return _tts.speak(text);
  }
}
