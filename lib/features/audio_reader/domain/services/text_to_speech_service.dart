import '../../../../core/audio/tts_voice.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/tts_event.dart';

/// Contract for on-device speech synthesis.
///
/// Implementations wrap a specific TTS backend (`flutter_tts`, itself a thin
/// wrapper over the OS's own `TextToSpeech`/`AVSpeechSynthesizer`) behind
/// this interface so the rest of the app never couples to the plugin. The
/// text read aloud never leaves the device either way — same on-device
/// guarantee OCR (§ privacy) already holds for the paper's contents.
abstract interface class TextToSpeechService {
  /// Speaks [text], replacing whatever is currently speaking.
  ///
  /// Answers only once the engine has taken the utterance — not when the
  /// reading ends. An engine that declines it, or never answers at all, is a
  /// failure and not a quiet success (F30-T09): the caller turns an `Ok`
  /// into a mini-player, and a bar over a silent engine never goes away
  /// (F30 RC-3).
  ///
  /// Failures:
  /// - [TtsFailure] — the engine could not start speaking.
  Future<Result<void, AppFailure>> speak(String text);

  /// Pauses the current utterance so [resume] can continue it later.
  Future<Result<void, AppFailure>> pause();

  /// Resumes an utterance previously paused with [pause].
  ///
  /// A no-op — not a failure — if nothing is paused, since a caller cannot
  /// otherwise tell "never started" apart from "already finished".
  Future<Result<void, AppFailure>> resume();

  /// Stops speaking and discards playback position.
  Future<Result<void, AppFailure>> stop();

  /// Sets the reading speed.
  ///
  /// [rate] ranges 0.0 (slowest) to 1.0 (fastest); the plugin normalizes it
  /// per platform, so the same value reads at a comparable pace on both.
  Future<Result<void, AppFailure>> setSpeechRate(double rate);

  /// Switches the voice used for subsequent [speak] calls.
  Future<Result<void, AppFailure>> setVoice(TtsVoice voice);

  /// Lists the voices installed on this device.
  Future<Result<List<TtsVoice>, AppFailure>> getVoices();

  /// The longest text the engine will take in one [speak], in UTF-16 code
  /// units — or `null` when the platform declares no limit (F30-T15).
  ///
  /// Android answers with `TextToSpeech.getMaxSpeechInputLength()`, 4000, and
  /// refuses anything longer in a way nothing downstream can see: the plugin
  /// parks the call, so [speak] never answers and no event ever arrives (F30
  /// RC-3). `ReadingQueue` asks for this so it can cut a long run into
  /// several utterances before the engine has the chance.
  ///
  /// Not a [Result]: there is nothing for a caller to report or recover
  /// from. A platform that does not implement the call — iOS does not — is
  /// indistinguishable here from one that declares no limit, and both mean
  /// the same thing to the only caller there is.
  Future<int?> getMaxInputLength();

  /// Throws away whatever [getVoices] is holding, so the next call asks the
  /// device again (F30-T04).
  ///
  /// [getVoices] is answered from a cache, because enumerating every voice of
  /// every installed engine is a slow platform call and it used to run on
  /// every single reading — a good part of the delay F30 RC-6 describes. The
  /// list only changes when the user installs or removes a voice, which means
  /// leaving the app, so this exists for the one flow that sends them out to
  /// do exactly that: F30-T07 tells a user with no Arabic voice to go and add
  /// one, and the answer must not still be "you have none" when they come
  /// back.
  void forgetVoices();

  /// The playback lifecycle, one event per state change — see [TtsEvent].
  Stream<TtsEvent> get events;
}
