import 'dart:async';

import 'package:flutter/services.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/pcm_format.dart';
import '../../domain/services/audio_encoder.dart';
import '../../domain/services/pcm_audio_sink.dart';

/// Bridges both [PcmAudioSink] and [AudioEncoder] to the Android host over
/// `com.war2aty.app/voice_audio` (F37-T13).
///
/// A control [MethodChannel] handles open / pause / resume / stop /
/// beginEncode / finishEncode / abortEncode. A [BasicMessageChannel] with
/// [BinaryCodec] carries the PCM chunks at ~96 KB/s. Dart does **not** fan
/// the stream: the Kotlin handler feeds every chunk to both [PcmPlayer] and
/// [AacEncoder], so [feed] is a documented no-op — the chunk was already
/// delivered by [write].
final class MethodChannelLiveAudioOutput implements PcmAudioSink, AudioEncoder {
  MethodChannelLiveAudioOutput({
    Duration pollInterval = const Duration(milliseconds: 200),
  }) : _pollInterval = pollInterval;

  static const _control = MethodChannel('com.war2aty.app/voice_audio');
  static const _pcm = BasicMessageChannel<ByteData?>(
    'com.war2aty.app/voice_audio_pcm',
    BinaryCodec(),
  );

  final Duration _pollInterval;
  final _positionController = StreamController<Duration>.broadcast(sync: true);
  Timer? _positionTimer;
  bool _sinkOpen = false;

  // ── PcmAudioSink ──────────────────────────────────────────────────

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Future<Result<void, AppFailure>> open(PcmFormat format) async {
    try {
      final ok = await _control.invokeMethod<bool>('open', {
        'sampleRate': format.sampleRate,
        'channels': format.channels,
        'bitsPerSample': format.bitsPerSample,
      });
      if (ok != true) return const Err(AudioPlaybackFailure());
      _sinkOpen = true;
      _startPositionPolling();
      return const Ok(null);
    } on MissingPluginException {
      return const Err(AudioPlaybackFailure());
    } on PlatformException {
      return const Err(AudioPlaybackFailure());
    }
  }

  @override
  Future<void> write(Uint8List chunk) async {
    if (!_sinkOpen) return;
    await _pcm.send(
      chunk.buffer.asByteData(chunk.offsetInBytes, chunk.lengthInBytes),
    );
  }

  @override
  Future<void> pause() async {
    try {
      await _control.invokeMethod<void>('pause');
    } on MissingPluginException {
      // No host — nothing to pause.
    } on PlatformException {
      // Best-effort.
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _control.invokeMethod<void>('resume');
    } on MissingPluginException {
      // No host.
    } on PlatformException {
      // Best-effort.
    }
  }

  @override
  Future<Duration> stop() async {
    _sinkOpen = false;
    _stopPositionPolling();
    try {
      final us = await _control.invokeMethod<int>('stop');
      final duration = Duration(microseconds: us ?? 0);
      _positionController.add(duration);
      return duration;
    } on MissingPluginException {
      return Duration.zero;
    } on PlatformException {
      return Duration.zero;
    }
  }

  // ── AudioEncoder ──────────────────────────────────────────────────

  @override
  Future<Result<void, AppFailure>> begin(PcmFormat format) async {
    try {
      final ok = await _control.invokeMethod<bool>('beginEncode', {
        'sampleRate': format.sampleRate,
        'channels': format.channels,
        'bitsPerSample': format.bitsPerSample,
      });
      if (ok != true) return const Err(AudioEncodingFailure());
      return const Ok(null);
    } on MissingPluginException {
      return const Err(AudioEncodingFailure());
    } on PlatformException {
      return const Err(AudioEncodingFailure());
    }
  }

  @override
  Future<void> feed(Uint8List chunk) async {
    // No-op: the Kotlin handler fans every chunk from [write] to both
    // PcmPlayer and AacEncoder, so the encoder already has this data.
  }

  @override
  Future<Result<Uint8List, AppFailure>> finish() async {
    try {
      final bytes = await _control.invokeMethod<Uint8List>('finishEncode');
      if (bytes == null || bytes.isEmpty) {
        return const Err(AudioEncodingFailure());
      }
      return Ok(bytes);
    } on MissingPluginException {
      return const Err(AudioEncodingFailure());
    } on PlatformException {
      return const Err(AudioEncodingFailure());
    }
  }

  @override
  Future<void> abort() async {
    try {
      await _control.invokeMethod<void>('abortEncode');
    } on MissingPluginException {
      // Nothing to abort.
    } on PlatformException {
      // Best-effort.
    }
  }

  // ── position polling ──────────────────────────────────────────────

  void _startPositionPolling() {
    _stopPositionPolling();
    _positionTimer = Timer.periodic(_pollInterval, (_) async {
      if (!_sinkOpen) return;
      try {
        final us = await _control.invokeMethod<int>('getPosition');
        if (us != null && _sinkOpen) {
          _positionController.add(Duration(microseconds: us));
        }
      } catch (_) {
        // Position polling is best-effort; a missed tick is not a failure.
      }
    });
  }

  void _stopPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}
