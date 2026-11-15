import 'dart:typed_data';

import '../../../../core/error/app_failure.dart';

/// A frame from the live reading session, as the transport saw it (F37).
///
/// Deliberately lower-level than the events the app shows: this union mirrors
/// what the service actually sends, so the one place that parses the wire has
/// nothing to decide. Turning these into something a screen can use — spans,
/// positions, a verdict on whether the read was verbatim — is the use case's
/// job.
///
/// The audio and the transcription arrive **interleaved but not in step**: a
/// frame may carry one, the other, or both. That is precisely why span
/// alignment anchors only on frames carrying both, and why a cumulative byte
/// count taken at the moment a transcript delta arrives measures *arrival*
/// order rather than speech time.
sealed class LiveVoiceEvent {
  const LiveVoiceEvent();
}

/// Raw PCM to play, in the session's agreed format.
///
/// Arrives faster than it speaks — the spike measured a 26-second read
/// delivered in 11–13 seconds — so these are played as they land and never
/// collected into a file first.
final class LivePcmChunk extends LiveVoiceEvent {
  const LivePcmChunk(this.bytes);

  final Uint8List bytes;

  @override
  String toString() => 'LivePcmChunk(${bytes.length} bytes)';
}

/// The service's own transcription of what it just spoke.
///
/// Incremental, and the only way the read is verified without a second
/// speech-to-text pass. Never logged: it is the paper's own words
/// (CLAUDE.md §7).
///
/// Note the wire asymmetry this union exists to absorb:
/// `outputAudioTranscription` is the key that *enables* this in the setup
/// frame, while the server sends the text at
/// `serverContent.outputTranscription.text`.
final class LiveTranscriptDelta extends LiveVoiceEvent {
  const LiveTranscriptDelta(this.text);

  final String text;

  @override
  String toString() => 'LiveTranscriptDelta(${text.length} chars)';
}

/// The service finished speaking the turn it was given.
final class LiveTurnComplete extends LiveVoiceEvent {
  const LiveTurnComplete();
}

/// The session ended before the turn was complete.
///
/// Carries an already-classified failure because the data layer is where wire
/// errors become `AppFailure`s; nothing above this has to know about close
/// codes. A `goAway`, a watchdog firing and a dropped socket all land here.
final class LiveSessionLost extends LiveVoiceEvent {
  const LiveSessionLost(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'LiveSessionLost($failure)';
}
