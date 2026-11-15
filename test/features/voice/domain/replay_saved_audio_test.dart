import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_replay_event.dart';
import 'package:war2aty/features/voice/domain/usecases/replay_saved_audio.dart';

import '../../../support/fakes.dart';

/// F37-T19 · the second phase: replaying a saved reading.
void main() {
  /// Three cards over the thirty seconds the fake player reports.
  const spans = [
    SpokenCardSpan(
      segmentId: 'type',
      start: Duration.zero,
      end: Duration(seconds: 10),
      exact: true,
    ),
    SpokenCardSpan(
      segmentId: 'amount',
      start: Duration(seconds: 10),
      end: Duration(seconds: 20),
      exact: true,
    ),
    SpokenCardSpan(
      segmentId: 'risk',
      start: Duration(seconds: 20),
      end: Duration(seconds: 30),
      exact: false,
    ),
  ];

  late FakeSavedAudioPlayer player;
  late ReplaySavedAudio replay;
  late List<VoiceReplayEvent> events;
  late StreamSubscription<VoiceReplayEvent> subscription;

  setUp(() {
    player = FakeSavedAudioPlayer();
    replay = ReplaySavedAudio(player);
    events = [];
  });

  tearDown(() async {
    await subscription.cancel();
    await player.dispose();
  });

  /// Lets the use case's awaits settle.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> start({
    String audioId = 'paper-1',
    List<SpokenCardSpan> withSpans = spans,
  }) async {
    subscription = replay(
      audioId: audioId,
      spans: withSpans,
    ).listen(events.add);
    await settle();
  }

  group('starting a replay', () {
    test('loads the stored id and plays it', () async {
      await start();

      expect(player.loaded, ['paper-1']);
      expect(player.plays, 1);
    });

    test('reports the length first, so the phase is seekable', () async {
      player.duration = const Duration(seconds: 42);

      await start();

      expect(events.first, const VoiceReplayReady(Duration(seconds: 42)));
    });

    test('a length the player could not determine is still a replay', () async {
      player.duration = Duration.zero;

      await start();

      expect(events, [const VoiceReplayReady(Duration.zero)]);
      expect(player.plays, 1);
    });

    test('nothing is played when the audio cannot be loaded', () async {
      player.failure = const FileStorageFailure();

      await start();

      expect(events, [const VoiceReplayFailed(FileStorageFailure())]);
      expect(player.plays, 0);
    });

    test('the store failure arrives as it was given', () async {
      player.failure = const FileEncryptionFailure();

      await start();

      expect(events, [const VoiceReplayFailed(FileEncryptionFailure())]);
    });

    test(
      'a player that refuses to start is reported, not left silent',
      () async {
        player.throwOnPlay = true;

        await start();

        expect(events.last, const VoiceReplayFailed(AudioPlaybackFailure()));
        // Everything it was holding is released on the way out.
        expect(player.stops, 1);
      },
    );
  });

  group('progress', () {
    test('a position is placed in the card it falls in', () async {
      await start();

      player.tick(const Duration(seconds: 12));
      await settle();

      expect(
        events.last,
        const VoiceReplayPositionChanged(
          position: Duration(seconds: 12),
          segmentId: 'amount',
        ),
      );
    });

    test('a position outside every span carries no card', () async {
      await start();

      player.tick(const Duration(seconds: 44));
      await settle();

      expect(
        events.last,
        const VoiceReplayPositionChanged(position: Duration(seconds: 44)),
      );
    });

    test('a replay with no spans still reports positions', () async {
      await start(withSpans: const []);

      player.tick(const Duration(seconds: 3));
      await settle();

      expect(
        events.last,
        const VoiceReplayPositionChanged(position: Duration(seconds: 3)),
      );
    });

    test('the end of the audio is reported', () async {
      await start();

      player.finish();
      await settle();

      expect(events.last, const VoiceReplayFinished());
    });

    test('the stream stays open after the end, so it can be seeked back '
        'into', () async {
      var closed = false;
      subscription = replay(
        audioId: 'paper-1',
        spans: spans,
      ).listen(events.add, onDone: () => closed = true);
      await settle();

      player.finish();
      await settle();

      expect(closed, isFalse);
      expect(await replay.seek(const Duration(seconds: 5)), isTrue);
      expect(player.seeks, [const Duration(seconds: 5)]);
    });
  });

  group('holding it', () {
    test('pause asks the player and says it is paused', () async {
      await start();

      expect(await replay.pause(), isTrue);
      expect(player.pauses, 1);
    });

    test('a second pause changes nothing', () async {
      await start();
      await replay.pause();

      expect(await replay.pause(), isFalse);
      expect(player.pauses, 1);
    });

    test('resume plays again', () async {
      await start();
      await replay.pause();

      expect(await replay.resume(), isTrue);
      expect(player.plays, 2);
    });

    test('resume with nothing paused changes nothing', () async {
      await start();

      expect(await replay.resume(), isFalse);
      expect(player.plays, 1);
    });

    test('a reading that reached its end counts as held', () async {
      await start();

      player.finish();
      await settle();

      // Not "already playing": the screen is drawing a play button, and it has
      // to do something.
      expect(await replay.pause(), isFalse);
      expect(await replay.resume(), isTrue);
    });

    test('resuming a finished reading starts the paper over', () async {
      await start();
      player.finish();
      await settle();

      await replay.resume();

      // The player was sitting on the last frame; playing from there would be
      // a voice the state claims is speaking and nobody can hear.
      expect(player.seeks, [Duration.zero]);
      expect(player.plays, 2);
    });

    test('dragging back first resumes from there, not from the top', () async {
      await start();
      player.finish();
      await settle();

      await replay.seek(const Duration(seconds: 8));
      await replay.resume();

      expect(player.seeks, [const Duration(seconds: 8)]);
      expect(player.plays, 2);
    });

    test('nothing to pause before a replay has started', () async {
      expect(await replay.pause(), isFalse);
      expect(await replay.resume(), isFalse);
      // Keeps the tear-down honest: there is still a subscription to cancel.
      await start();
    });
  });

  group('seeking', () {
    test('a position inside the audio is passed through', () async {
      await start();

      expect(await replay.seek(const Duration(seconds: 7)), isTrue);
      expect(player.seeks, [const Duration(seconds: 7)]);
    });

    test('a position before the start lands at the start', () async {
      await start();

      await replay.seek(const Duration(seconds: -4));

      expect(player.seeks, [Duration.zero]);
    });

    test('a position past the end lands at the end', () async {
      await start();

      await replay.seek(const Duration(minutes: 5));

      expect(player.seeks, [const Duration(seconds: 30)]);
    });

    test('an unknown length clamps nothing but the start', () async {
      player.duration = Duration.zero;
      await start();

      await replay.seek(const Duration(seconds: 90));

      expect(player.seeks, [const Duration(seconds: 90)]);
    });

    test('nothing to seek before a replay has started', () async {
      expect(await replay.seek(Duration.zero), isFalse);
      expect(player.seeks, isEmpty);
      await start();
    });
  });

  group('ending it', () {
    test('cancelling the subscription stops the player', () async {
      await start();

      await subscription.cancel();
      await settle();

      expect(player.stops, 1);
      // And nothing is left to pause.
      expect(await replay.pause(), isFalse);
    });

    test('positions after a cancel are not reported', () async {
      await start();
      final before = events.length;

      await subscription.cancel();
      player.tick(const Duration(seconds: 9));
      await settle();

      expect(events.length, before);
    });

    test('leaving while the audio is decrypting plays nothing', () async {
      // Decrypting a third of a megabyte is not instant, and a paper that
      // started talking after the user walked away would be the one thing
      // cancelling has to prevent.
      final hold = player.holdLoad = Completer<void>();
      subscription = replay(audioId: 'paper-1').listen(events.add);
      await settle();

      await subscription.cancel();
      hold.complete();
      await settle();

      expect(player.plays, 0);
      expect(events, isEmpty);
      // The decoder it loaded into is let go.
      expect(player.stops, 1);
    });

    test('a replay that started meanwhile keeps the player', () async {
      final hold = player.holdLoad = Completer<void>();
      final abandoned = replay(audioId: 'paper-1').listen(events.add);
      await settle();
      await abandoned.cancel();

      // A second replay takes the player before the first one's load answers.
      player.holdLoad = null;
      subscription = replay(audioId: 'paper-2').listen(events.add);
      await settle();
      hold.complete();
      await settle();

      expect(player.plays, 1);
      expect(player.stops, 0, reason: 'the live replay was not silenced');
    });

    test('a second replay supersedes the first', () async {
      await start();
      final first = subscription;

      final second = <VoiceReplayEvent>[];
      subscription = replay(audioId: 'paper-2').listen(second.add);
      await settle();

      expect(player.loaded, ['paper-1', 'paper-2']);
      expect(player.stops, 1);
      expect(second.first, const VoiceReplayReady(Duration(seconds: 30)));
      await first.cancel();
    });

    test('the superseded replay reports nothing more', () async {
      await start();
      final first = subscription;
      final before = events.length;

      subscription = replay(audioId: 'paper-2').listen((_) {});
      await settle();
      player.tick(const Duration(seconds: 2));
      await settle();

      // The positions now belong to the second replay; the first one's stream
      // has let go of its subscription.
      expect(events.length, before);
      await first.cancel();
    });
  });

  group('privacy', () {
    test('no event carries a word of the paper', () async {
      await start();
      player.tick(const Duration(seconds: 12));
      player.finish();
      await settle();

      for (final event in events) {
        expect(event.toString(), isNot(contains('فاتورة')));
        expect(event.toString(), isNot(contains('كهرباء')));
      }
    });
  });
}
