import 'dart:async';
import 'dart:typed_data';

import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/encrypted_audio_store.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_event.dart';
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
        sink: _SilentSink(),
        encoder: _SilentEncoder(),
        audioStore: _EmptyAudioStore(),
        deviceReader: _MuteDeviceReader(),
        verify: const VerifyVerbatimRead(normalise),
        align: const AlignSegmentsToAudio(normalise),
      ),
      ReplaySavedAudio(player),
    );
  }

  final session = RecordingLiveSession();
  final player = FakeSavedAudioPlayer();
  late final VoicePlaybackCubit cubit;

  int get liveReadsStarted => session.starts;
  List<String> get replaysLoaded => player.loaded;

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    await cubit.close();
    session.dispose();
    await player.dispose();
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

  void dispose() {
    if (!_events.isClosed) unawaited(_events.close());
  }
}

final class _SilentSink implements PcmAudioSink {
  @override
  Future<Result<void, AppFailure>> open(PcmFormat format) async =>
      const Ok(null);

  @override
  Future<void> write(Uint8List chunk) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<Duration> stop() async => Duration.zero;

  @override
  Stream<Duration> get position => const Stream.empty();
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
  @override
  Stream<VoiceReadEvent> get events => const Stream.empty();

  @override
  Future<Result<Duration, AppFailure>> read(VoiceTurnText turn) =>
      Completer<Result<Duration, AppFailure>>().future;

  @override
  Future<void> stop() async {}
}
