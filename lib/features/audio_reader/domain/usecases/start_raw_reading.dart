import '../../../../core/audio/tts_voice.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';
import 'normalize_spoken_numbers.dart';
import 'select_voice_for_reading.dart';

/// Starts reading a plain text string aloud — the raw-text counterpart of
/// [StartReading], used on the OCR review screen where there is no
/// [AnalysisResult] yet and [BuildReadingText] has nothing to build from.
///
/// Applies [normalizeSpokenNumbers] so phone numbers, dates, and amounts are
/// spoken the same way they would be in a full analysis reading, then hands the
/// result to [TextToSpeechService.speak].
///
/// Answers with the spoken text's length on success, in UTF-16 code units —
/// the same contract [StartReading] follows, so [AudioReaderCubit] can turn
/// later `TtsProgressed` events into a 0-to-1 fraction without this use case
/// handing back the text itself.
final class StartRawReading {
  const StartRawReading(this._selectVoice, this._tts);

  final SelectVoiceForReading _selectVoice;
  final TextToSpeechService _tts;

  Future<Result<int, AppFailure>> call({
    required String text,
    TtsVoice? preferredVoice,
  }) async {
    final normalized = normalizeSpokenNumbers(text).trim();
    if (normalized.isEmpty) {
      return const Err(TtsFailure());
    }
    await _applyDefaultVoiceFor(normalized, preferredVoice);
    return (await _tts.speak(normalized)).map((_) => normalized.length);
  }

  /// Best-effort voice selection — same reasoning as [StartReading]'s own
  /// `_applyDefaultVoiceFor`: a failure here should not stop the reading.
  Future<void> _applyDefaultVoiceFor(
    String text,
    TtsVoice? preferredVoice,
  ) async {
    if (preferredVoice != null) {
      await _tts.setVoice(preferredVoice);
      return;
    }
    final voices = (await _tts.getVoices()).valueOrNull;
    if (voices == null) return;
    final voice = _selectVoice(text, voices);
    if (voice != null) await _tts.setVoice(voice);
  }
}
