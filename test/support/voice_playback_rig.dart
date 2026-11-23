import 'dart:async';
import 'dart:typed_data';

import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/encrypted_audio_store.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_event.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';
import 'package:war2aty/features/voice/domain/services/audio_encoder.dart';
import 'package:war2aty/features/voice/domain/services/device_voice_reader.dart';
import 'package:war2aty/features/voice/domain/services/live_voice_session.dart';
import 'package:war2aty/features/voice/domain/services/pcm_audio_sink.dart';
import 'package:war2aty/features/voice/domain/usecases/align_segments_to_audio.dart';
import 'package:war2aty/features/voice/domain/usecases/build_voice_turn_text.dart';
import 'package:war2aty/features/voice/domain/usecases/normalise_arabic_for_diff.dart';
import 'package:war2aty/features/voice/domain/usecases/read_paper_aloud.dart';
import 'package:war2aty/features/voice/domain/usecases/replay_saved_audio.dart';
import 'package:war2aty/features/voice/domain/usecases/verify_verbatim_read.dart';

import 'fakes.dart';

final class VoicePlaybackRig {
  VoicePlaybackRig() {
    const normalise = NormaliseArabicForDiff();
    cubit = VoicePlaybackCubit(
      ReadPaperAloud(
        openSession: () => session,
        sink: _sink,
        encoder: _SilentEncoder(),
        audioStore: _EmptyAudioStore(),
        deviceReader: _deviceReader,
        verify: const VerifyVerbatimRead(normalise),
        align: const AlignSegmentsToAudio(normalise),
      ),
      ReplaySavedAudio(player),
    );
  }

  final session = RecordingLiveSession();
  final player = FakeSavedAudioPlayer();
  final _sink = _ClockedSink();
  final _deviceReader = _MuteDeviceReader();
  late final VoicePlaybackCubit cubit;

  int get liveReadsStarted => session.starts;
  List<String> get replaysLoaded => player.loaded;

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void failReadWith(AppFailure failure) {
    _sink.openResult = Err<void, AppFailure>(failure);
    _deviceReader.finish(Err<Duration, AppFailure>(failure));
  }

  void emitWholeLiveRead({
    required List<VoiceSegment> segments,
    int audioSeconds = 3,
  }) {
    session
      ..emit(
        LivePcmChunk(
          Uint8List(PcmFormat.geminiLive.bytesPerSecond * audioSeconds),
        ),
      )
      ..emit(LiveTranscriptDelta(const BuildVoiceTurnText()(segments).text))
      ..emit(const LiveTurnComplete());
  }

  Future<void> dispose() async {
    await cubit.close();
    session.dispose();
    await player.dispose();
    _sink.dispose();
  }
}

final class RecordingLiveSession implements LiveVoiceSession {
  final _events = StreamController<LiveVoiceEvent>();

  var starts = 0;

  @override
  PcmFormat get format => PcmFormat.geminiLive;

  @override
  Stream<LiveVoiceEvent> get events => _events.stream;

  @override
  Future<Result<void, AppFailure>> start(String turnText) async {
    starts++;
    return const Ok(null);
  }

  @override
  Future<void> cancel() async {
    if (!_events.isClosed) unawaited(_events.close());
  }

  void emit(LiveVoiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void dispose() {
    if (!_events.isClosed) unawaited(_events.close());
  }
}

final class _ClockedSink implements PcmAudioSink {
  final _positions = StreamController<Duration>.broadcast(sync: true);

  var _written = 0;
  var _played = Duration.zero;
  Result<void, AppFailure> openResult = const Ok(null);

  @override
  Future<Result<void, AppFailure>> open(PcmFormat format) async => openResult;

  @override
  Future<void> write(Uint8List chunk) async {
    _written += chunk.length;
    _played = PcmFormat.geminiLive.durationOfBytes(_written);
    _positions.add(_played);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<Duration> stop() async => _played;

  @override
  Stream<Duration> get position => _positions.stream;

  void dispose() {
    if (!_positions.isClosed) unawaited(_positions.close());
  }
}

final class _SilentEncoder implements AudioEncoder {
  @override
  Future<Result<void, AppFailure>> begin(PcmFormat format) async =>
      const Ok(null);

  @override
  Future<void> feed(Uint8List chunk) async {}

  @override
  Future<Result<Uint8List, AppFailure>> finish() async =>
      Ok(Uint8List.fromList(const [1]));

  @override
  Future<void> abort() async {}
}

final class _EmptyAudioStore implements EncryptedAudioStore {
  @override
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  }) async => Ok('voice_audio/$id');

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async =>
      const Err(FileStorageFailure());

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<bool> exists(String id) async => false;
}

final class _MuteDeviceReader implements DeviceVoiceReader {
  final _completer = Completer<Result<Duration, AppFailure>>();

  @override
  Stream<VoiceReadEvent> get events => const Stream.empty();

  @override
  Future<Result<Duration, AppFailure>> read(VoiceTurnText turn) =>
      _completer.future;

  @override
  Future<void> stop() async {}

  void finish(Result<Duration, AppFailure> outcome) {
    if (!_completer.isCompleted) _completer.complete(outcome);
  }
}
