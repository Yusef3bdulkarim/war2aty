import '../default_reading_voice_store.dart';
import '../tts_voice.dart';

/// Persists the user's choice for «صوت القراءة» (F11-T07). `null` resets it
/// back to «الصوت الافتراضي» (the automatic script match).
final class SetDefaultReadingVoice {
  const SetDefaultReadingVoice(this._store);

  final DefaultReadingVoiceStore _store;

  Future<void> call(TtsVoice? voice) => _store.writeVoice(voice);
}
