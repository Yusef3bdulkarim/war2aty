import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/tts_event.dart';
import '../entities/tts_voice.dart';

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

  /// The playback lifecycle, one event per state change — see [TtsEvent].
  Stream<TtsEvent> get events;
}
