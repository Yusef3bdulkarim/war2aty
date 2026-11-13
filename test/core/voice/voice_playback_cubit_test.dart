import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/encrypted_audio_store.dart';
import 'package:war2aty/core/voice/voice_playback_cubit.dart';
import 'package:war2aty/core/voice/voice_playback_state.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
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

import '../../support/fakes.dart';

/// F37-T19 · the spine's cubit.
///
/// Driven through the **real** use cases over fake services, wired the way DI
/// will wire them (T21): what this cubit is, is the translation of two very
/// different readings into one state, so faking the ladder would have tested
/// the translation against a fiction of itself.
void main() {
  /// The same page the ladder's own tests read: 24 words over three cards.
  const segments = [
    VoiceSegment(
      id: 'type',
      text: 'فاتورة كهرباء من شركة شمال القاهرة لتوزيع الكهرباء',
    ),
    VoiceSegment(
      id: 'amount',
      text: 'المبلغ المطلوب مية وخمسين جنيه وآخر موعد للدفع يوم عشرين نوفمبر',
    ),
    VoiceSegment(id: 'risk', text: 'لو مدفعتش الكهربا ممكن تتقطع'),
  ];

  const buildTurn = BuildVoiceTurnText();
  final turn = buildTurn(segments);

  /// One second of audio in the Live format.
  const oneSecond = 48000;

  late _FakeLiveSession session;
  late _FakeSink sink;
  late _FakeEncoder encoder;
  late _FakeAudioStore store;
  late _FakeDeviceReader device;
  late FakeSavedAudioPlayer player;
  late ReadPaperAloud readPaperAloud;
  late ReplaySavedAudio replaySavedAudio;
  late VoicePlaybackCubit cubit;

  setUp(() {
    session = _FakeLiveSession();
    sink = _FakeSink();
    encoder = _FakeEncoder();
    store = _FakeAudioStore();
    device = _FakeDeviceReader();
    player = FakeSavedAudioPlayer();

    const normalise = NormaliseArabicForDiff();
    readPaperAloud = ReadPaperAloud(
      openSession: () => session,
      sink: sink,
      encoder: encoder,
      audioStore: store,
      deviceReader: device,
      verify: const VerifyVerbatimRead(normalise),
      align: const AlignSegmentsToAudio(normalise),
    );
    replaySavedAudio = ReplaySavedAudio(player);
    cubit = VoicePlaybackCubit(readPaperAloud, replaySavedAudio);
  });

  tearDown(() async {
    await cubit.close();
    session.dispose();
    await sink.dispose();
    await device.dispose();
    await player.dispose();
  });

  /// Lets the use cases' awaits and the fakes' streams settle.
  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Starts a read and waits for the tier to announce itself.
  Future<void> read({String audioId = 'paper-1'}) async {
    await cubit.readAloud(segments: segments, audioId: audioId);
    await settle();
  }

  /// A whole Live read: audio, the service's transcription of it, and the end
  /// of the turn.
  Future<void> finishLiveRead() async {
    session.emit(LivePcmChunk(Uint8List(oneSecond * 3)));
    session.emit(LiveTranscriptDelta(turn.text));
    session.emit(const LiveTurnComplete());
    await settle();
  }

  group('reading a paper aloud', () {
    test('says it is preparing before any engine has answered', () async {
      final states = <VoicePlaybackState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.readAloud(segments: segments, audioId: 'paper-1');

      expect(cubit.state, const VoicePlaybackPreparing());
      await settle();
      expect(states.first, const VoicePlaybackPreparing());
      await sub.cancel();
    });

    test('the preparing state offers nothing to press', () async {
      await cubit.readAloud(segments: segments, audioId: 'paper-1');

      expect(cubit.state.canPause, isFalse);
      expect(cubit.state.canSeek, isFalse);
      expect(cubit.state.isSpeaking, isFalse);
    });

    test('the Live tier announces itself, with no seeking', () async {
      await read();

      expect(
        cubit.state,
        const VoicePlaybackStreaming(engine: VoiceEngine.geminiLive),
      );
      expect(cubit.state.canSeek, isFalse);
      expect(cubit.state.canPause, isTrue);
      expect(cubit.state.isSpeaking, isTrue);
    });

    test('what the speaker has played moves the state', () async {
      await read();

      // Two seconds of audio written, and therefore played.
      session.emit(LivePcmChunk(Uint8List(oneSecond * 2)));
      await settle();

      final state = cubit.state as VoicePlaybackStreaming;
      expect(state.position, const Duration(seconds: 2));
      expect(state.engine, VoiceEngine.geminiLive);
    });

    test('the spans land while the paper is still being spoken', () async {
      await read();
      // Audio the speaker has not finished playing yet, so the read is not
      // over when the spans resolve.
      sink.emitClock = false;
      session.emit(LivePcmChunk(Uint8List(oneSecond * 4)));
      session.emit(LiveTranscriptDelta(turn.text));
      session.emit(const LiveTurnComplete());
      await settle();

      final state = cubit.state as VoicePlaybackStreaming;
      expect(state.spans, hasLength(3));
      expect(state.canSeek, isFalse, reason: 'still streaming (D7)');
    });

    test('a card with no position in it yet is not highlighted', () async {
      await read();

      expect((cubit.state as VoicePlaybackStreaming).segmentId, isNull);
    });

    test('the highlight is held through a gap between cards', () async {
      // Driven on the device tier, which is where the gap is real: an offset
      // inside T06's separator reports no card at all (T18).
      sink.openResult = const Err(AudioPlaybackFailure());
      await read();

      device.emit(
        const VoiceReadPositionChanged(
          position: Duration(seconds: 2),
          segmentId: 'type',
        ),
      );
      await settle();

      device.emit(
        const VoiceReadPositionChanged(position: Duration(seconds: 3)),
      );
      await settle();

      final state = cubit.state as VoicePlaybackStreaming;
      expect(state.segmentId, 'type');
      expect(state.position, const Duration(seconds: 3));
    });

    test('a finished read says the paper can be replayed', () async {
      await read();
      await finishLiveRead();

      final state = cubit.state as VoicePlaybackReadFinished;
      expect(state.canReplay, isTrue);
      expect(state.outcome.audioSaved, isTrue);
      expect(state.canPause, isFalse);
      expect(state.canSeek, isFalse);
    });

    test('a read whose audio was not saved cannot be replayed', () async {
      encoder.finishResult = const Err(AudioEncodingFailure());
      await read();
      await finishLiveRead();

      expect((cubit.state as VoicePlaybackReadFinished).canReplay, isFalse);
    });

    test('the device tier announces itself and declares no pause', () async {
      sink.openResult = const Err(AudioPlaybackFailure());

      await read();

      expect(
        cubit.state,
        const VoicePlaybackStreaming(engine: VoiceEngine.deviceTts),
      );
      expect(cubit.state.canPause, isFalse);
      expect(cubit.state.canSeek, isFalse);
    });

    test('a device read reports its own positions and cards', () async {
      sink.openResult = const Err(AudioPlaybackFailure());
      await read();

      device.emit(
        const VoiceReadPositionChanged(
          position: Duration(seconds: 2),
          segmentId: 'amount',
        ),
      );
      await settle();

      expect(
        cubit.state,
        const VoicePlaybackStreaming(
          engine: VoiceEngine.deviceTts,
          position: Duration(seconds: 2),
          segmentId: 'amount',
        ),
      );
    });

    test('a device read that finishes leaves no file to replay', () async {
      sink.openResult = const Err(AudioPlaybackFailure());
      await read();

      device.finish(const Ok(Duration(seconds: 80)));
      await settle();

      final state = cubit.state as VoicePlaybackReadFinished;
      expect(state.outcome.engine, VoiceEngine.deviceTts);
      expect(state.canReplay, isFalse);
    });

    test('a paper no tier could read ends in the failure, intact', () async {
      sink.openResult = const Err(AudioPlaybackFailure());
      await read();

      device.finish(const Err(NoArabicVoiceFailure()));
      await settle();

      expect(cubit.state, const VoicePlaybackFailed(NoArabicVoiceFailure()));
    });

    test('a second read replaces the first', () async {
      await read();

      await cubit.readAloud(segments: segments, audioId: 'paper-2');
      await settle();

      // The first read was stopped: its session was given back and its
      // speaker released.
      expect(session.cancels, greaterThanOrEqualTo(1));
      expect(cubit.state, isA<VoicePlaybackStreaming>());
    });
  });

  group('holding the voice', () {
    test('pausing a Live read holds the speaker', () async {
      await read();

      await cubit.pause();

      expect(sink.pauses, 1);
      final state = cubit.state as VoicePlaybackStreaming;
      expect(state.isPaused, isTrue);
      expect(state.isSpeaking, isFalse);
    });

    test('resuming it carries on from where it stopped', () async {
      await read();
      await cubit.pause();

      await cubit.resume();

      expect(sink.resumes, 1);
      expect((cubit.state as VoicePlaybackStreaming).isPaused, isFalse);
    });

    test('a second pause changes nothing', () async {
      await read();
      await cubit.pause();

      await cubit.pause();

      expect(sink.pauses, 1);
    });

    test('the device tier is not paused, and does not claim to be', () async {
      sink.openResult = const Err(AudioPlaybackFailure());
      await read();

      await cubit.pause();

      expect(sink.pauses, 0);
      expect((cubit.state as VoicePlaybackStreaming).isPaused, isFalse);
    });

    test('nothing to pause before a read has started', () async {
      await cubit.pause();

      expect(cubit.state, const VoicePlaybackIdle());
      expect(sink.pauses, 0);
    });

    test('a position landing mid-pause does not lose the pause', () async {
      await read();
      // The speaker reports where it reached while the pause is in flight —
      // five times a second, it will. The hold belongs on the reading as it
      // is *now*, not as it was when the button was pressed.
      sink.tickOnPause = const Duration(seconds: 2);

      await cubit.pause();

      final state = cubit.state as VoicePlaybackStreaming;
      expect(state.isPaused, isTrue);
      expect(state.position, const Duration(seconds: 2));
    });

    test('a read that finished while the pause was in flight wins', () async {
      await read();
      // The pause is asked for and the read ends before it is answered.
      final pausing = cubit.pause();
      await finishLiveRead();
      await pausing;

      expect(cubit.state, isA<VoicePlaybackReadFinished>());
    });
  });

  group('replaying a saved paper', () {
    test('replays the paper that was just read, with its spans', () async {
      await read();
      await finishLiveRead();

      await cubit.replay();
      await settle();

      expect(player.loaded, ['paper-1']);
      final state = cubit.state as VoicePlaybackFile;
      expect(state.duration, const Duration(seconds: 30));
      expect(state.spans, hasLength(3));
    });

    test('the second phase can be seeked and paused', () async {
      await read();
      await finishLiveRead();
      await cubit.replay();
      await settle();

      expect(cubit.state.canSeek, isTrue);
      expect(cubit.state.canPause, isTrue);
    });

    test('a saved paper opened fresh carries its own id and spans', () async {
      const spans = [
        SpokenCardSpan(
          segmentId: 'amount',
          start: Duration(seconds: 4),
          end: Duration(seconds: 9),
          exact: true,
        ),
      ];

      await cubit.replay(audioId: 'old-paper', spans: spans);
      await settle();

      expect(player.loaded, ['old-paper']);
      expect((cubit.state as VoicePlaybackFile).spans, spans);
    });

    test('with nothing read and no id, there is nothing to replay', () async {
      await cubit.replay();
      await settle();

      expect(cubit.state, const VoicePlaybackIdle());
      expect(player.loaded, isEmpty);
    });

    test('a replay that cannot be loaded is reported', () async {
      player.failure = const FileStorageFailure();

      await cubit.replay(audioId: 'old-paper');
      await settle();

      expect(cubit.state, const VoicePlaybackFailed(FileStorageFailure()));
    });

    test('positions highlight the card they fall in', () async {
      await cubit.replay(
        audioId: 'old-paper',
        spans: const [
          SpokenCardSpan(
            segmentId: 'amount',
            start: Duration(seconds: 4),
            end: Duration(seconds: 9),
            exact: true,
          ),
        ],
      );
      await settle();

      player.tick(const Duration(seconds: 5));
      await settle();

      final state = cubit.state as VoicePlaybackFile;
      expect(state.position, const Duration(seconds: 5));
      expect(state.segmentId, 'amount');
    });

    test(
      'reaching the end leaves it paused at the end, still seekable',
      () async {
        await cubit.replay(audioId: 'old-paper');
        await settle();

        player.finish();
        await settle();

        final state = cubit.state as VoicePlaybackFile;
        expect(state.isPaused, isTrue);
        expect(state.position, state.duration);
        expect(state.canSeek, isTrue);
      },
    );

    test('a finished replay can be played again', () async {
      await cubit.replay(audioId: 'old-paper');
      await settle();
      player.finish();
      await settle();

      await cubit.resume();

      // The button the finished state draws actually does something.
      expect(player.plays, 2);
      expect((cubit.state as VoicePlaybackFile).isPaused, isFalse);
    });

    test('seek moves the player, not the state', () async {
      await cubit.replay(audioId: 'old-paper');
      await settle();

      await cubit.seek(const Duration(seconds: 12));

      expect(player.seeks, [const Duration(seconds: 12)]);
      // The player reports where it actually landed; nothing is assumed here.
      expect((cubit.state as VoicePlaybackFile).position, Duration.zero);
    });

    test('seeking is refused while the audio is still streaming', () async {
      await read();

      await cubit.seek(const Duration(seconds: 5));

      expect(player.seeks, isEmpty);
    });

    test('a card can be jumped to by id', () async {
      await read();
      await finishLiveRead();
      await cubit.replay();
      await settle();

      final spans = (cubit.state as VoicePlaybackFile).spans;
      await cubit.seekToSegment('risk');

      expect(player.seeks, [
        spans.firstWhere((span) => span.segmentId == 'risk').start,
      ]);
    });

    test('a card nothing placed is not jumped to', () async {
      await cubit.replay(audioId: 'old-paper');
      await settle();

      await cubit.seekToSegment('amount');

      expect(player.seeks, isEmpty);
    });

    test('pausing a replay holds the player', () async {
      await cubit.replay(audioId: 'old-paper');
      await settle();

      await cubit.pause();

      expect(player.pauses, 1);
      expect((cubit.state as VoicePlaybackFile).isPaused, isTrue);

      await cubit.resume();

      expect(player.plays, 2);
      expect((cubit.state as VoicePlaybackFile).isPaused, isFalse);
    });

    test('a replay replaces a read that is still speaking', () async {
      await read();

      await cubit.replay(audioId: 'old-paper');
      await settle();

      expect(session.cancels, greaterThanOrEqualTo(1));
      expect(cubit.state, isA<VoicePlaybackFile>());
    });
  });

  group('stopping', () {
    test('stop ends the read and gives the session back', () async {
      await read();

      await cubit.stop();
      await settle();

      expect(cubit.state, const VoicePlaybackIdle());
      expect(session.cancels, greaterThanOrEqualTo(1));
      expect(sink.stops, greaterThanOrEqualTo(1));
    });

    test('stop ends a replay', () async {
      await cubit.replay(audioId: 'old-paper');
      await settle();

      await cubit.stop();
      await settle();

      expect(cubit.state, const VoicePlaybackIdle());
      expect(player.stops, 1);
    });

    test('stop with nothing playing is a no-op', () async {
      await cubit.stop();

      expect(cubit.state, const VoicePlaybackIdle());
    });

    test('closing the cubit silences the voice', () async {
      await read();

      await cubit.close();
      await settle();

      expect(session.cancels, greaterThanOrEqualTo(1));
      expect(device.stops, greaterThanOrEqualTo(1));
    });

    test('a read that ends after the cubit closed changes nothing', () async {
      await read();
      await cubit.close();

      await finishLiveRead();

      expect(cubit.state, isA<VoicePlaybackStreaming>());
    });
  });

  group('privacy', () {
    test('no state carries a word of the paper', () async {
      final states = <VoicePlaybackState>[];
      final sub = cubit.stream.listen(states.add);

      await read();
      await finishLiveRead();
      await cubit.replay();
      await settle();
      player.tick(const Duration(seconds: 5));
      await settle();

      expect(states, isNotEmpty);
      for (final state in states) {
        expect(state.toString(), isNot(contains('فاتورة')));
        expect(state.toString(), isNot(contains('كهرباء')));
        expect(state.toString(), isNot(contains('مية')));
      }
      await sub.cancel();
    });
  });
}

/// A Live session fed by the test.
final class _FakeLiveSession implements LiveVoiceSession {
  final _events = StreamController<LiveVoiceEvent>();

  var starts = 0;
  var cancels = 0;

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
    cancels++;
    if (!_events.isClosed) unawaited(_events.close());
  }

  void emit(LiveVoiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void dispose() {
    if (!_events.isClosed) unawaited(_events.close());
  }
}

/// The speaker, and the playback clock behind it.
final class _FakeSink implements PcmAudioSink {
  final _positions = StreamController<Duration>.broadcast(sync: true);

  Result<void, AppFailure> openResult = const Ok(null);

  /// Whether a write advances the clock, as a real speaker would.
  bool emitClock = true;

  /// A position landing while the pause is still being asked for — the
  /// 200 ms poll (T13) is not going to wait politely.
  Duration? tickOnPause;

  var pauses = 0;
  var resumes = 0;
  var stops = 0;
  var written = 0;
  var played = Duration.zero;

  @override
  Future<Result<void, AppFailure>> open(PcmFormat format) async => openResult;

  @override
  Future<void> write(Uint8List chunk) async {
    written += chunk.length;
    if (emitClock) tick(PcmFormat.geminiLive.durationOfBytes(written));
  }

  @override
  Future<void> pause() async {
    pauses++;
    final position = tickOnPause;
    if (position != null) tick(position);
  }

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<Duration> stop() async {
    stops++;
    return played;
  }

  @override
  Stream<Duration> get position => _positions.stream;

  void tick(Duration position) {
    played = position;
    _positions.add(position);
  }

  Future<void> dispose() => _positions.close();
}

final class _FakeEncoder implements AudioEncoder {
  Result<void, AppFailure> beginResult = const Ok(null);
  Result<Uint8List, AppFailure> finishResult = Ok(Uint8List(0));

  @override
  Future<Result<void, AppFailure>> begin(PcmFormat format) async => beginResult;

  @override
  Future<void> feed(Uint8List chunk) async {}

  @override
  Future<Result<Uint8List, AppFailure>> finish() async =>
      finishResult.isOk ? Ok(Uint8List.fromList([1, 2, 3])) : finishResult;

  @override
  Future<void> abort() async {}
}

final class _FakeAudioStore implements EncryptedAudioStore {
  final List<String> stored = [];

  @override
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  }) async {
    stored.add(id);
    return Ok('voice_audio/$id');
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async =>
      const Err(FileStorageFailure());

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<bool> exists(String id) async => stored.contains(id);
}

/// The fallback tier, answering whatever the test needs.
final class _FakeDeviceReader implements DeviceVoiceReader {
  final _events = StreamController<VoiceReadEvent>.broadcast(sync: true);
  Completer<Result<Duration, AppFailure>>? _reading;

  var stops = 0;

  @override
  Stream<VoiceReadEvent> get events => _events.stream;

  @override
  Future<Result<Duration, AppFailure>> read(VoiceTurnText turn) {
    final reading = _reading = Completer<Result<Duration, AppFailure>>();
    return reading.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    finish(const Ok(Duration(seconds: 1)));
  }

  void emit(VoiceReadEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void finish(Result<Duration, AppFailure> outcome) {
    final reading = _reading;
    if (reading == null || reading.isCompleted) return;
    reading.complete(outcome);
  }

  Future<void> dispose() => _events.close();
}
