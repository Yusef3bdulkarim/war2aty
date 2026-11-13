import 'dart:async';

import '../../../../core/error/app_failure.dart';
import '../entities/spoken_card_span.dart';
import '../entities/voice_replay_event.dart';
import '../services/saved_audio_player.dart';
import 'spoken_span_timeline.dart';

/// Replays a reading that was already saved (F37-T19).
///
/// The spine's second phase, and the cheap one: the paper is read aloud from
/// the encrypted `.m4a` a Live read left behind, with no network, no quota and
/// no second verbatim check — and, because the whole file is there, with a
/// position that can be jumped to.
///
/// It is shaped like [ReadPaperAloud] on purpose: `call` returns a
/// single-subscription stream, the playback starts when it is listened to, and
/// cancelling the subscription stops it. A screen that can drive one can drive
/// the other, and the cubit above them has one habit rather than two.
///
/// **Spans are handed in, not derived.** They were measured when the paper was
/// read (T07/T18) and stored with it (F38); nothing about a replay can produce
/// them. Replaying with none is valid — the reading plays, and every position
/// carries `segmentId: null`, which asks the screen to hold whatever it is
/// showing.
///
/// **Privacy.** Nothing here is logged: the id is opaque, the positions are
/// numbers, and the audio is bytes this use case never looks inside
/// (CLAUDE.md §7).
final class ReplaySavedAudio {
  ReplaySavedAudio(this._player);

  final SavedAudioPlayer _player;

  /// The replay in flight, or `null` when nothing is playing.
  ///
  /// One player, therefore one replay: a second [call] that is listened to
  /// stops the first rather than leaving two readings on one speaker.
  _Replay? _current;

  /// Replays the audio saved under [audioId], reporting progress against
  /// [spans].
  ///
  /// [audioId] is the same opaque key the read was stored under — not a
  /// document id, deliberately.
  Stream<VoiceReplayEvent> call({
    required String audioId,
    List<SpokenCardSpan> spans = const [],
  }) {
    final out = StreamController<VoiceReplayEvent>();
    final replay = _Replay(out: out);
    out.onListen = () {
      unawaited(_start(replay, audioId, spans));
    };
    out.onCancel = () async {
      replay.cancelled = true;
      await _release(replay);
    };
    return out.stream;
  }

  /// Holds the replay in place, and answers whether it is now paused.
  ///
  /// `false` means nothing changed: there is no replay, or it is already
  /// paused. The streaming phase's [ReadPaperAloud.pause] answers on the same
  /// terms, which is what lets the cubit treat the two phases alike.
  Future<bool> pause() async {
    final replay = _current;
    if (replay == null || replay.paused) return false;
    replay.paused = true;
    await _player.pause();
    return true;
  }

  /// Resumes a replay [pause] paused, and answers whether it is now playing.
  Future<bool> resume() async {
    final replay = _current;
    if (replay == null || !replay.paused) return false;
    replay.paused = false;
    await _player.play();
    return true;
  }

  /// Jumps to [position], clamped into the audio.
  ///
  /// Answers whether the jump happened — `false` with no replay in flight.
  /// A negative [position] lands at the start, and one past the end lands at
  /// the end rather than being refused: the caller is usually a finger on a
  /// scrubber, and a tap a few milliseconds past the last frame means the end.
  Future<bool> seek(Duration position) async {
    final replay = _current;
    if (replay == null) return false;
    var target = position;
    if (target < Duration.zero) target = Duration.zero;
    if (replay.duration > Duration.zero && target > replay.duration) {
      target = replay.duration;
    }
    await _player.seek(target);
    return true;
  }

  Future<void> _start(
    _Replay replay,
    String audioId,
    List<SpokenCardSpan> spans,
  ) async {
    final out = replay.out;

    // A replay that was already playing is over: one player, one speaker.
    final previous = _current;
    if (previous != null) await _release(previous);

    final loaded = await _player.load(audioId);

    // Decrypting a third of a megabyte is not instant, and the listener can
    // leave inside it. Starting the playback now would read someone their
    // paper on a screen they walked away from, which is the one thing
    // cancelling has to prevent (T17 closed the same hole in the ladder).
    if (replay.cancelled) {
      // The player may since have been handed to a replay that started after
      // this one, so it is only released if nothing else took it.
      if (loaded.isOk && _current == null) await _stopQuietly();
      return;
    }

    if (loaded.failureOrNull case final failure?) {
      out.add(VoiceReplayFailed(failure));
      if (!out.isClosed) await out.close();
      return;
    }
    final duration = loaded.valueOrNull ?? Duration.zero;

    replay.duration = duration;
    _current = replay;

    // Subscribed before the first frame plays, so a position reported the
    // instant playback starts is not lost.
    replay.positions = _player.position.listen((position) {
      if (out.isClosed) return;
      out.add(
        VoiceReplayPositionChanged(
          position: position,
          segmentId: segmentAt(spans, position),
        ),
      );
    });
    replay.completions = _player.completions.listen((_) {
      // The stream stays open: the audio is still loaded, and a user who hears
      // their paper to the end may well drag back to the bit they missed.
      if (!out.isClosed) out.add(const VoiceReplayFinished());
    });

    out.add(VoiceReplayReady(duration));

    try {
      await _player.play();
    } on Object {
      // The player refused to start after accepting the audio. Reported rather
      // than left as a scrubber that never moves (CLAUDE.md §3).
      await _release(replay);
      if (!out.isClosed) {
        out.add(const VoiceReplayFailed(AudioPlaybackFailure()));
        await out.close();
      }
    }
  }

  /// Ends [replay] and releases the player, absorbing a throw from either.
  ///
  /// By the time this runs the replay is over on every path — cancelled,
  /// superseded, or refused — and a player that throws on its way out must not
  /// leave the subscriptions behind it alive.
  ///
  /// The player is only stopped for the replay that *holds* it. A replay that
  /// never got that far — cancelled while its audio was being decrypted, or
  /// refused by the store — would otherwise silence whatever is playing now.
  Future<void> _release(_Replay replay) async {
    final holdsPlayer = identical(_current, replay);
    if (holdsPlayer) _current = null;
    try {
      await replay.positions?.cancel();
      await replay.completions?.cancel();
    } on Object {
      // Nothing left to recover, and nothing in reach worth logging.
    }
    if (holdsPlayer) await _stopQuietly();
  }

  /// Stops the player, absorbing a throw: every caller is already past
  /// deciding anything.
  Future<void> _stopQuietly() async {
    try {
      await _player.stop();
    } on Object {
      // The replay is over either way.
    }
  }
}

/// One replay in flight: the stream it reports on, and what it holds.
final class _Replay {
  _Replay({required this.out});

  final StreamController<VoiceReplayEvent> out;

  /// The audio's full length, as the player reported it on load — the bound
  /// every seek is clamped into. Zero until the load answers.
  Duration duration = Duration.zero;

  bool paused = false;

  /// Whether the listener left. Set before the load answers, in the window
  /// where there is nothing yet to release.
  bool cancelled = false;

  StreamSubscription<Duration>? positions;
  StreamSubscription<void>? completions;
}
