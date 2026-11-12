import 'dart:typed_data';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/pcm_format.dart';

/// Plays raw audio as it arrives (F37).
///
/// An interface because only the Android implementation exists for this pivot
/// and iOS follows later. The implementation also owns two things no caller
/// above it can do correctly:
///
/// - **Audio focus.** The device's own text-to-speech requests it for us; a raw
///   audio track does not, so without it a paper is read over the top of an
///   incoming phone call.
/// - **Sole ownership of the speaker.** The device-TTS tier and this sink must
///   never both play, which can otherwise happen in the instant a read falls
///   from one tier to the other.
abstract interface class PcmAudioSink {
  /// Reserves the speaker and prepares to accept [format].
  ///
  /// An `Err` means nothing can be played — the caller falls back to the other
  /// tier rather than reading to a user who will hear silence.
  Future<Result<void, AppFailure>> open(PcmFormat format);

  /// Queues [chunk] for playback.
  ///
  /// Returns as soon as the chunk is handed over, not when it has been heard:
  /// audio arrives at roughly twice real time, so this always runs ahead of the
  /// voice.
  Future<void> write(Uint8List chunk);

  /// Stops the voice without discarding what has not been played yet.
  ///
  /// The producer cannot be paused — the service keeps streaming regardless —
  /// so pausing is a consumer-side act and the rest of the paper accumulates
  /// until [resume].
  Future<void> pause();

  Future<void> resume();

  /// Releases the speaker and reports how much was actually played.
  ///
  /// The duration is what the device played, never what was written: the two
  /// differ by whatever is still queued, and using the written amount is what
  /// would run a screen's highlight ahead of the voice.
  Future<Duration> stop();

  /// How much has actually been played, as it is played.
  ///
  /// The single source of truth for the reading's position, so that a segment
  /// span measured in bytes and a position measured in played frames share one
  /// timeline.
  Stream<Duration> get position;
}
