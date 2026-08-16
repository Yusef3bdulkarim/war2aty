import '../default_reading_voice_store.dart';
import '../tts_voice.dart';

/// Reads the user's preferred default reading voice (F11-T07) — `null` means
/// «الصوت الافتراضي», i.e. `SelectVoiceForReading`'s automatic script match,
/// which stays the behaviour until the user explicitly picks a device voice
/// from Settings.
final class GetDefaultReadingVoice {
  const GetDefaultReadingVoice(this._store);

  final DefaultReadingVoiceStore _store;

  Future<TtsVoice?> call() => _store.readVoice();
}
