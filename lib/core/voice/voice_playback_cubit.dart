import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/voice/domain/entities/spoken_card_span.dart';
import '../../features/voice/domain/entities/voice_read_event.dart';
import '../../features/voice/domain/entities/voice_replay_event.dart';
import '../../features/voice/domain/entities/voice_segment.dart';
import '../../features/voice/domain/usecases/read_paper_aloud.dart';
import '../../features/voice/domain/usecases/replay_saved_audio.dart';
import '../../features/voice/domain/usecases/spoken_span_timeline.dart';
import 'voice_playback_state.dart';

/// Drives the voice: reading a paper aloud, and replaying a saved one
/// (F37-T19).
///
/// The spine's one presentation-facing object. Everything under it reports and
/// decides nothing about a screen; everything above it — F39's capture flow,
/// F40's result screen, F41's screens — holds this and nothing else.
///
/// **It is the whole of the voice's state machine**, and there is not much of
/// it: the two phases, the lead-in to them, what a finished read left behind,
/// and a failure. See [VoicePlaybackState].
///
/// Lives in `core/` rather than in the `voice` feature for the reason
/// `AudioReaderCubit` does: the screens that build it belong to other features
/// (F39's capture, F40's result, F41's saved papers), and a feature screen
/// never imports another feature. F37 wires nothing into a tree — this exists
/// to be injected, and the scope fence keeps it that way.
///
/// **Depends on use cases only** (CLAUDE.md §B2). The tier ladder and the
/// replay are both use cases that own a reading in flight, which is why
/// pausing goes through them rather than through a sink or a player this layer
/// is not allowed to see.
///
/// **Privacy.** Nothing here is logged, and nothing it holds is a word of the
/// paper: segments pass straight through to the use case, and the state is
/// positions, ids and booleans (CLAUDE.md §7).
final class VoicePlaybackCubit extends Cubit<VoicePlaybackState> {
  VoicePlaybackCubit(this._readPaperAloud, this._replaySavedAudio)
    : super(const VoicePlaybackIdle());

  final ReadPaperAloud _readPaperAloud;
  final ReplaySavedAudio _replaySavedAudio;

  /// The read in flight. Cancelling it is what stops the voice (T17), so this
  /// is also the stop.
  StreamSubscription<VoiceReadEvent>? _readSubscription;

  /// The replay in flight. Cancelled the same way, for the same reason.
  StreamSubscription<VoiceReplayEvent>? _replaySubscription;

  /// The key the last read was stored under, so [replay] does not need to be
  /// told it again — `null` before anything has been read here.
  String? _audioId;

  /// The spans of the last reading, carried across the phase change: a replay
  /// cannot measure them, and the read that produced them already did.
  List<SpokenCardSpan> _spans = const [];

  /// Reads [segments] aloud, in page order, and saves the audio under
  /// [audioId].
  ///
  /// Replaces whatever was playing. The tier is chosen under here, not by the
  /// caller: a screen asks for the paper to be read and is told which engine
  /// answered, because that decides what it may offer — only a Live read
  /// leaves a file behind.
  ///
  /// [audioId] is an opaque key, deliberately not a document id (F37 stays
  /// clear of F36's schema).
  Future<void> readAloud({
    required List<VoiceSegment> segments,
    required String audioId,
  }) async {
    if (isClosed) return;
    await _silence();
    if (isClosed) return;
    _audioId = audioId;
    _spans = const [];
    emit(const VoicePlaybackPreparing());
    _readSubscription = _readPaperAloud(
      segments: segments,
      audioId: audioId,
    ).listen(_onReadEvent, onDone: () => _readSubscription = null);
  }

  /// Replays a reading already saved on this phone — no network, no quota, and
  /// seekable.
  ///
  /// [audioId] defaults to the paper this cubit last read, which is the common
  /// case: the user heard it, wants the amount again, and taps replay. A saved
  /// paper opened fresh (F41) passes both its own [audioId] and the [spans]
  /// that were stored with it, since nothing about a replay can measure them.
  Future<void> replay({String? audioId, List<SpokenCardSpan>? spans}) async {
    if (isClosed) return;
    final id = audioId ?? _audioId;
    // Nothing has been read here and no paper was named: there is nothing to
    // replay, and inventing a key would only produce a storage failure.
    if (id == null) return;
    await _silence();
    if (isClosed) return;
    _audioId = id;
    if (spans != null) _spans = spans;
    emit(const VoicePlaybackPreparing());
    _replaySubscription = _replaySavedAudio(
      audioId: id,
      spans: _spans,
    ).listen(_onReplayEvent, onDone: () => _replaySubscription = null);
  }

  /// Holds the voice where it is.
  ///
  /// A no-op where the state says it cannot be done — nothing playing, already
  /// paused, or a tier with no pause ([VoicePlaybackState.canPause]) — and a
  /// no-op if the use case refuses, so the state never claims a silence the
  /// user is not hearing.
  Future<void> pause() async {
    if (isClosed) return;
    switch (state) {
      case final VoicePlaybackStreaming current when current.canPause:
        if (current.isPaused) return;
        final paused = await _readPaperAloud.pause();
        if (isClosed || !paused) return;
        _holdStreaming(paused: true);
      case final VoicePlaybackFile current:
        if (current.isPaused) return;
        final paused = await _replaySavedAudio.pause();
        if (isClosed || !paused) return;
        _holdFile(paused: true);
      case _:
        return;
    }
  }

  /// Continues a voice [pause] held, from where it stopped. A no-op on the
  /// same three grounds [pause] is.
  Future<void> resume() async {
    if (isClosed) return;
    switch (state) {
      case final VoicePlaybackStreaming current when current.canPause:
        if (!current.isPaused) return;
        final resumed = await _readPaperAloud.resume();
        if (isClosed || !resumed) return;
        _holdStreaming(paused: false);
      case final VoicePlaybackFile current:
        if (!current.isPaused) return;
        final resumed = await _replaySavedAudio.resume();
        if (isClosed || !resumed) return;
        _holdFile(paused: false);
      case _:
        return;
    }
  }

  /// Jumps to [position].
  ///
  /// Only the second phase can: a read that is still arriving has nothing to
  /// jump to, and the service cannot replay part of a turn (D7). The position
  /// itself is not emitted — the player reports where it lands, which is the
  /// only position that is true.
  Future<void> seek(Duration position) async {
    if (isClosed) return;
    if (!state.canSeek) return;
    await _replaySavedAudio.seek(position);
  }

  /// Jumps to the start of the card [segmentId] — what F40's card-tapping
  /// needs.
  ///
  /// A no-op when the reading has no span for that card, which is honest
  /// rather than approximate: a paper whose spans never resolved cannot say
  /// where a card begins, and jumping to a guess would read the user the wrong
  /// part of their bill.
  Future<void> seekToSegment(String segmentId) async {
    if (isClosed) return;
    final spans = switch (state) {
      final VoicePlaybackFile current => current.spans,
      _ => const <SpokenCardSpan>[],
    };
    for (final span in spans) {
      if (span.segmentId == segmentId) {
        await seek(span.start);
        return;
      }
    }
  }

  /// Stops the voice and clears the player.
  ///
  /// This is how a user leaving the screen is not followed by their paper
  /// being read to them — and, while a Live read is in flight, how the session
  /// is given back, which is the scarce resource on that service (T17).
  Future<void> stop() async {
    if (isClosed) return;
    await _silence();
    if (isClosed) return;
    emit(const VoicePlaybackIdle());
  }

  /// Turns the tier ladder's events into the first phase.
  ///
  /// The envelope is the ladder's: one [VoiceReadStarted] per attempt — a
  /// retry restarts Live from word one, so the state is rebuilt rather than
  /// updated — and exactly one terminal event however many tiers were spent.
  void _onReadEvent(VoiceReadEvent event) {
    if (isClosed) return;
    switch (event) {
      case VoiceReadStarted(:final engine):
        emit(VoicePlaybackStreaming(engine: engine, spans: _spans));

      case VoiceReadSpansResolved(:final spans):
        _spans = spans;
        if (state case final VoicePlaybackStreaming current) {
          emit(
            current.copyWith(
              spans: spans,
              // The position the user is at now falls in one of the cards that
              // just resolved, so the highlight appears with them rather than
              // at the next position event.
              segmentId: segmentAt(spans, current.position),
            ),
          );
        }

      case VoiceReadPositionChanged(:final position, :final segmentId):
        if (state case final VoicePlaybackStreaming current) {
          // `segmentId: null` means "nothing placed here", not "no card": the
          // gap between two cards keeps the highlight the user is looking at,
          // which `copyWith` does by leaving an unset id alone.
          emit(current.copyWith(position: position, segmentId: segmentId));
        }

      case VoiceReadCompleted(:final outcome):
        _spans = outcome.spans;
        emit(VoicePlaybackReadFinished(outcome));

      case VoiceReadFailed(:final failure):
        emit(VoicePlaybackFailed(failure));
    }
  }

  /// Turns a replay's events into the second phase.
  void _onReplayEvent(VoiceReplayEvent event) {
    if (isClosed) return;
    switch (event) {
      case VoiceReplayReady(:final duration):
        emit(VoicePlaybackFile(duration: duration, spans: _spans));

      case VoiceReplayPositionChanged(:final position, :final segmentId):
        if (state case final VoicePlaybackFile current) {
          emit(current.copyWith(position: position, segmentId: segmentId));
        }

      case VoiceReplayFinished():
        if (state case final VoicePlaybackFile current) {
          // Still the file phase: the audio is loaded, and dragging back into
          // it is the point of this phase.
          emit(current.copyWith(position: current.duration, isPaused: true));
        }

      case VoiceReplayFailed(:final failure):
        emit(VoicePlaybackFailed(failure));
    }
  }

  /// Writes a hold onto the reading **as it is now**, not as it was when the
  /// pause was asked for.
  ///
  /// A pause is two turns long — ask the tier, then say so — and the Live tier
  /// reports a new position about five times a second, so the state almost
  /// always moved while the tier was answering. Re-reading it is what keeps a
  /// voice that has actually stopped from being drawn as still speaking.
  ///
  /// Nothing is written if the phase itself changed in that gap: a read that
  /// finished, failed, or fell to a tier that cannot pause has the truer
  /// state, and a pause belongs to the reading it was asked of.
  void _holdStreaming({required bool paused}) {
    if (state case final VoicePlaybackStreaming latest when latest.canPause) {
      emit(latest.copyWith(isPaused: paused));
    }
  }

  /// The same, for the replay. See [_holdStreaming].
  void _holdFile({required bool paused}) {
    if (state case final VoicePlaybackFile latest) {
      emit(latest.copyWith(isPaused: paused));
    }
  }

  /// Stops whatever is playing, without emitting anything.
  ///
  /// Cancelling the subscription is the stop in both phases: the ladder
  /// abandons the session, releases the speaker and discards the partial file
  /// (T17), and the replay stops the player.
  Future<void> _silence() async {
    final read = _readSubscription;
    final replay = _replaySubscription;
    _readSubscription = null;
    _replaySubscription = null;
    await read?.cancel();
    await replay?.cancel();
  }

  @override
  Future<void> close() async {
    // The voice stops with the screen that owned it. Nothing is emitted: a
    // closed cubit has no state anyone is watching, and the thing that matters
    // is that the speaker and the Live session are let go.
    await _silence();
    await super.close();
  }
}
