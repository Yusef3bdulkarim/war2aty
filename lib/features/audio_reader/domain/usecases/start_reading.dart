import '../../../../core/audio/tts_voice.dart';
import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/result/result.dart';
import '../services/text_to_speech_service.dart';
import 'build_reading_text.dart';
import 'select_voice_for_reading.dart';

/// Starts reading one [ReadingMode] of a result aloud (F10-T04).
///
/// Combines [BuildReadingText] — which turns the mode into the text — with
/// [TextToSpeechService.speak], so the mini-player's cubit depends on one use
/// case rather than a builder and a service directly (architecture rule:
/// cubits depend on use cases only). Also applies [SelectVoiceForReading]'s
/// default voice ahead of speaking (F10-T07), unless [call]'s own
/// `preferredVoice` overrides it with the user's persisted Settings choice
/// (F11-T07).
///
/// Answers with the spoken text's length on success, in UTF-16 code units —
/// the same unit `TtsProgressed`'s own `start`/`end` are measured in — so the
/// cubit can turn later progress events into a 0-to-1 fraction (F10-T08)
/// without this use case handing back the text itself (kept out of the
/// cubit; nothing about a document's content needs to travel further than it
/// already does to be spoken).
final class StartReading {
  const StartReading(this._buildReadingText, this._selectVoice, this._tts);

  final BuildReadingText _buildReadingText;
  final SelectVoiceForReading _selectVoice;
  final TextToSpeechService _tts;

  Future<Result<int, AppFailure>> call({
    required AnalysisResult result,
    required ReadingMode mode,
    required AppStrings strings,
    TtsVoice? preferredVoice,
  }) async {
    final text = _buildReadingText(
      result: result,
      mode: mode,
      strings: strings,
    );
    await _applyDefaultVoiceFor(text, preferredVoice);
    return (await _tts.speak(text)).map((_) => text.length);
  }

  /// Best-effort: switches to [preferredVoice] if the user has picked one in
  /// Settings (F11-T07), otherwise to a voice matching [text]'s script when
  /// the device has one.
  ///
  /// Nothing here is surfaced as a failure — unlike the speed the user
  /// explicitly chooses in the options sheet (`SetReadingSpeed`), picking a
  /// voice is not something the user asked *this particular reading* for, so
  /// a device with no matching voice, or a `getVoices`/`setVoice` call that
  /// fails, should not stop — or interrupt — the reading; it proceeds on
  /// whatever voice the engine already had.
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
