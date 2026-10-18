import '../services/text_to_speech_service.dart';

/// Gets the reading engine ready before the user asks for a reading
/// (F30-T06).
///
/// Everything slow about starting a reading happens the first time: the OS
/// engine finishes binding its service, and `getVoices` enumerates every
/// voice of every installed engine across the platform channel. Both used to
/// land on the tap, which is a good part of the 1–3 seconds the owner waited
/// (F30 RC-6).
///
/// Asking for the voices here moves both costs off the tap. The service
/// caches the list (F30-T04), so this is the call that fills the cache, and
/// the reading itself then finds it already there. The timing is generous:
/// the result screen appears while the user is still reading the summary on
/// it, seconds before anyone reaches for «الاستماع».
///
/// The engine's maximum utterance length is asked for at the same time and
/// cached the same way (F30-T15). It is a second channel round trip the
/// reading would otherwise make, and the two are asked for together rather
/// than one after the other, since neither waits on the other's answer.
///
/// Nothing is reported back. A warm-up that fails has cost the user nothing
/// — the reading will ask again — so there is no failure here worth
/// interrupting anyone over, and nothing for a caller to decide. In
/// particular, the engine may answer with no voices at all while it is still
/// binding; the service deliberately does not cache that, so a warm-up that
/// lands too early simply leaves the work to the reading, exactly as before.
final class WarmUpReader {
  const WarmUpReader(this._tts);

  final TextToSpeechService _tts;

  Future<void> call() =>
      Future.wait<Object?>([_tts.getVoices(), _tts.getMaxInputLength()]);
}
