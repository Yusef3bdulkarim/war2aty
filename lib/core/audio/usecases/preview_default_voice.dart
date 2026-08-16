import '../../../features/audio_reader/domain/services/text_to_speech_service.dart';
import '../../../features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reading_speed.dart';
import '../tts_voice.dart';

/// Speaks [sampleText] at [speed] so «تجربة الصوت» (F11-T07) lets the user
/// hear the settings they are about to save before confirming them.
///
/// [voice] is whichever the user has already picked — `null` for «الصوت
/// الافتراضي», in which case this falls back to `SelectVoiceForReading`'s own
/// automatic script match for [sampleText], the same way a real reading would
/// (F10-T07).
final class PreviewDefaultVoice {
  const PreviewDefaultVoice(this._tts, this._selectVoice);

  final TextToSpeechService _tts;
  final SelectVoiceForReading _selectVoice;

  Future<Result<void, AppFailure>> call({
    required String sampleText,
    required ReadingSpeed speed,
    TtsVoice? voice,
  }) async {
    final rateOutcome = await _tts.setSpeechRate(speed.rate);
    if (rateOutcome.failureOrNull case final failure?) return Err(failure);
    await _applyVoice(sampleText, voice);
    return _tts.speak(sampleText);
  }

  /// Best-effort, the same reasoning `StartReading._applyDefaultVoiceFor`
  /// documents for itself: a device with no matching voice, or a
  /// `getVoices`/`setVoice` call that fails, should not stop the preview —
  /// it still plays, at whatever voice the engine already had.
  Future<void> _applyVoice(String sampleText, TtsVoice? voice) async {
    if (voice != null) {
      await _tts.setVoice(voice);
      return;
    }
    final voices = (await _tts.getVoices()).valueOrNull;
    if (voices == null) return;
    final matched = _selectVoice(sampleText, voices);
    if (matched != null) await _tts.setVoice(matched);
  }
}
