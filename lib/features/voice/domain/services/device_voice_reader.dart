import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/voice_read_event.dart';
import '../usecases/build_voice_turn_text.dart';

/// The fallback tier: the device's own engine reading the paper (F37-T17).
///
/// Declared here, implemented in T18 over the `flutter_tts` stack that F30 and
/// F31 already shipped — voice selection, number normalisation and chunking
/// included. It exists as its own interface so that `ReadPaperAloud` can own
/// the ladder without importing the reading queue, and so the tier can be
/// faked in the ladder's own tests.
///
/// **It does not announce itself.** The envelope — [VoiceReadStarted],
/// [VoiceReadCompleted], [VoiceReadFailed] — belongs to `ReadPaperAloud`,
/// which is the only thing that knows this is the last tier. An adapter that
/// emitted [VoiceReadFailed] of its own would contradict that event's
/// contract: it is emitted once every fallback is spent, and the adapter
/// cannot know that.
abstract interface class DeviceVoiceReader {
  /// Reads [turn] aloud and answers when the reading has **ended**.
  ///
  /// Deliberately unlike `TextToSpeechService.speak`, which answers once the
  /// engine has merely *taken* the utterance: the ladder has to know when the
  /// paper has actually been read, and a tier that answered early would report
  /// a completed reading over a voice still talking.
  ///
  /// `Ok` carries how long the reading lasted. An `Err` means the paper was
  /// not read — [NoArabicVoiceFailure] when the device has no Arabic voice
  /// installed, which is the one the screen may offer the system TTS settings
  /// for (F30-T07).
  ///
  /// [turn] is document content and is never logged (CLAUDE.md §7).
  Future<Result<Duration, AppFailure>> read(VoiceTurnText turn);

  /// Progress while [read] runs, in F37's own shape.
  ///
  /// [VoiceReadPositionChanged] as the engine advances, and at most one
  /// [VoiceReadSpansResolved] — T18 derives both from `TtsEvent`'s character
  /// offsets against [VoiceTurnText.offsets], which is what gives the fallback
  /// tier the same auto-scroll the Live tier has.
  Stream<VoiceReadEvent> get events;

  /// Stops a reading in progress, whether or not it finished.
  Future<void> stop();
}
