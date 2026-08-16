import '../../../features/audio_reader/domain/services/text_to_speech_service.dart';
import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../tts_voice.dart';

/// Lists the device's installed [TtsVoice]s for the «صوت القراءة» picker
/// (F11-T07).
///
/// A thin forward onto [TextToSpeechService.getVoices] — kept as its own use
/// case, like the audio-reader feature's own `SetReadingSpeed`, so
/// `SettingsCubit` depends on a use case rather than the service directly
/// (architecture rule).
final class GetAvailableVoices {
  const GetAvailableVoices(this._tts);

  final TextToSpeechService _tts;

  Future<Result<List<TtsVoice>, AppFailure>> call() => _tts.getVoices();
}
