import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/fixed_line_player.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';

/// F37-T20 · `SpeakFixedLine`.
///
/// Small on purpose: the use case's whole job is to turn a [VoiceLine] into the
/// right asset path and hand it to the player. What is worth pinning is that it
/// reaches **no engine** — the point of the bundled lines — and that a player
/// failure comes back as a failure instead of escaping as an exception onto a
/// screen that only wanted to speak.
void main() {
  late _FakeFixedLinePlayer player;
  late SpeakFixedLine speak;

  setUp(() {
    player = _FakeFixedLinePlayer();
    speak = SpeakFixedLine(player);
  });

  test('plays the asset path of the line it is given', () async {
    final result = await speak(VoiceLine.failOffline);

    expect(result.isOk, isTrue);
    expect(player.played, ['assets/voice_lines/fail_offline.m4a']);
  });

  test(
    'every line resolves to a path the player is actually asked for',
    () async {
      // One id wrong here is one screen that says nothing, so the mapping is
      // asserted for all of them rather than for a sample.
      for (final line in VoiceLine.values) {
        await speak(line);
      }

      expect(
        player.played,
        VoiceLine.values.map((line) => line.assetPath).toList(),
      );
    },
  );

  test('returns the player failure rather than throwing', () async {
    player.failure = const AudioPlaybackFailure();

    final result = await speak(VoiceLine.noArabicVoice);

    expect(result.isErr, isTrue);
    expect(result.failureOrNull, isA<AudioPlaybackFailure>());
  });

  test('stop reaches the player', () async {
    await speak(VoiceLine.waitingReading);
    await speak.stop();

    expect(player.stops, 1);
  });

  test('stop is forwarded even with nothing playing', () async {
    // The screen does not track whether its line has finished; it just stops on
    // the way out. A use case that guessed would guess wrong.
    await speak.stop();

    expect(player.stops, 1);
  });
}

final class _FakeFixedLinePlayer implements FixedLinePlayer {
  final List<String> played = [];
  int stops = 0;
  int disposals = 0;
  AppFailure? failure;

  @override
  Future<Result<void, AppFailure>> play(String assetPath) async {
    if (failure != null) return Err(failure!);
    played.add(assetPath);
    return const Ok(null);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposals++;
}
