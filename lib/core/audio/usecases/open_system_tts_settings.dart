import '../../../features/audio_reader/domain/services/text_to_speech_service.dart';
import '../../platform/system_tts_settings.dart';

/// Sends the user to the system's text-to-speech settings, where a reading
/// voice can be installed (F30-T07).
///
/// The way out of [NoArabicVoiceFailure]: a phone whose engine ships no
/// Arabic voice cannot read an Arabic paper at all, and the user is the only
/// one who can fix that.
///
/// [isAvailable] is asked before the way out is offered, so the button never
/// appears on a phone where it would do nothing.
final class OpenSystemTtsSettings {
  const OpenSystemTtsSettings(this._settings, this._tts);

  final SystemTtsSettings _settings;
  final TextToSpeechService _tts;

  /// Whether there is a settings screen to offer at all.
  Future<bool> isAvailable() => _settings.isAvailable();

  /// Answers false when nothing could be opened, rather than throwing — the
  /// caller keeps its message on screen either way.
  ///
  /// Forgets the cached voice list on the way out (F30-T04). The whole point
  /// of sending the user there is that they install a voice, and the cached
  /// answer would still say the device has none when they came back.
  Future<bool> call() async {
    _tts.forgetVoices();
    return _settings.open();
  }
}
