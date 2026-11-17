import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../error/app_failure.dart';
import '../result/result.dart';
import 'fixed_line_player.dart';

/// Plays a bundled fixed line with `just_audio` (F37-T20).
///
/// The lines are app assets, not a user's paper, so there is nothing here to
/// decrypt: `setAsset` reads them straight out of the bundle. That is the whole
/// reason this is a separate player from [JustAudioEncryptedPlayer] — the
/// encrypted one exists to keep a reading of someone's document off the disk in
/// plaintext, and a fixed UI line has no such content.
///
/// Lives in `core/` beside its interface, following
/// `encrypted_audio_store.dart` / `file_encrypted_audio_store.dart`: F39, F40
/// and F41 all speak fixed lines, and a feature screen never imports another
/// feature.
final class JustAudioFixedLinePlayer implements FixedLinePlayer {
  JustAudioFixedLinePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Completer<void>? _playToEndCompleter;
  bool _stopRequested = false;

  @override
  Future<Result<void, AppFailure>> play(String assetPath) async {
    final pending = _playToEndCompleter;
    if (pending != null && !pending.isCompleted) pending.complete();
    _playToEndCompleter = null;
    try {
      // Single-flight: whatever is still speaking is a message the user has
      // already been given, and two of them at once is neither.
      await _player.stop();
      await _player.setAsset(assetPath);
    } on Object {
      // A missing or unplayable asset. `voice_line_test` makes this
      // unreachable in a shipped build; it is reported rather than thrown so a
      // screen cannot be taken down by a line it only wanted to speak.
      return const Err(AudioPlaybackFailure());
    }

    // Not awaited: `play()` completes when the LINE does, which would hold the
    // caller for seconds. Errors after this point are swallowed on purpose —
    // the audio has started, and there is no second thing to tell the user.
    unawaited(_player.play().onError((_, _) {}));
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> playToEnd(String assetPath) async {
    final pending = _playToEndCompleter;
    if (pending != null && !pending.isCompleted) pending.complete();
    _playToEndCompleter = null;
    _stopRequested = false;
    try {
      await _player.stop();
      await _player.setAsset(assetPath);
    } on Object {
      if (_stopRequested) {
        _stopRequested = false;
        return const Ok(null);
      }
      return const Err(AudioPlaybackFailure());
    }

    final completer = Completer<void>();
    _playToEndCompleter = completer;

    final subscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !completer.isCompleted) {
        completer.complete();
      }
    });

    unawaited(
      _player.play().onError((_, _) {
        if (!completer.isCompleted) completer.complete();
      }),
    );

    await completer.future;
    await subscription.cancel();
    if (identical(_playToEndCompleter, completer)) {
      _playToEndCompleter = null;
    }
    return const Ok(null);
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    final pending = _playToEndCompleter;
    if (pending != null && !pending.isCompleted) pending.complete();
    _playToEndCompleter = null;
    await _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
