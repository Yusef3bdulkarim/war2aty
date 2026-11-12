import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/live_voice_event.dart';
import '../entities/pcm_format.dart';

/// One reading session with the live voice service (F37).
///
/// Single-use and single-turn: [start] opens a session, speaks the text once,
/// and the session is finished. It is not a conversation, even though the
/// service behind it is a chat model — which is exactly why the verbatim
/// instruction and `temperature: 0` are fixed in the implementation rather than
/// passed in. Those settings are what produced a 0.0 % word error rate in
/// F36-T02's spike, and a caller able to vary them could silently reopen the
/// one question that could have invalidated the product.
///
/// Reading the paper is the implementation's only job. It does not play, encode,
/// store, verify or align anything; it reports frames and lets the use case
/// decide.
abstract interface class LiveVoiceSession {
  /// The format the audio in [events] will arrive in.
  PcmFormat get format;

  /// Opens the session and asks for [turnText] to be read aloud.
  ///
  /// Returns once the service has accepted the turn, not once it has been
  /// spoken — the audio arrives on [events]. An `Err` means nothing will
  /// arrive at all, so the caller falls back rather than waiting.
  ///
  /// [turnText] is document content and is never logged (CLAUDE.md §7).
  Future<Result<void, AppFailure>> start(String turnText);

  /// Audio, transcription and the session's end, in arrival order.
  ///
  /// Closes after a `LiveTurnComplete` or a `LiveSessionLost`. Single
  /// subscription: there is one consumer, and fanning a 96 KB/s audio stream
  /// out to several would mean buffering all of it.
  Stream<LiveVoiceEvent> get events;

  /// Abandons the session, whether or not it finished.
  ///
  /// Safe to call twice, and safe to call before [start]. The caller is
  /// expected to call it on every path, including success: concurrent sessions
  /// are the scarce resource on this service — a handful per key — so a socket
  /// left open after a read denies the next user a voice.
  Future<void> cancel();
}
