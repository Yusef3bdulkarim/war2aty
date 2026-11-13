import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/encrypted_audio_store.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_event.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';
import 'package:war2aty/features/voice/domain/services/audio_encoder.dart';
import 'package:war2aty/features/voice/domain/services/device_voice_reader.dart';
import 'package:war2aty/features/voice/domain/services/live_voice_session.dart';
import 'package:war2aty/features/voice/domain/services/pcm_audio_sink.dart';
import 'package:war2aty/features/voice/domain/usecases/align_segments_to_audio.dart';
import 'package:war2aty/features/voice/domain/usecases/build_voice_turn_text.dart';
import 'package:war2aty/features/voice/domain/usecases/normalise_arabic_for_diff.dart';
import 'package:war2aty/features/voice/domain/usecases/read_paper_aloud.dart';
import 'package:war2aty/features/voice/domain/usecases/verify_verbatim_read.dart';

/// F37-T17 · the tier ladder.
///
/// Every path the ladder can take is driven from the outside: a fake session
/// feeds frames, a fake sink is the playback clock, and the device tier answers
/// whatever the test needs. No timers run — the fake sink's clock reaches the
/// end of the audio by the time the drain is waited on, except in the one test
/// that deliberately withholds it.
void main() {
  // A page of 24 words: 8 + 11 + 5. The counts matter — the prefix check only
  // speaks after twenty words have been heard.
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

  /// What the service would transcribe of a perfect read.
  final perfectTranscript = turn.text;

  /// The same read with its last two words wrong — 4 errors over 24 words is
  /// 16.7 %, which is not verbatim, while the prefix check that ran on it saw
  /// only 8.7 % and let the read continue. That gap is the whole «late
  /// mismatch» case: by the time it is known, the user has heard the paper.
  final lateMismatchTranscript = perfectTranscript.replaceFirst(
    'ممكن تتقطع',
    'بكرة الصبح',
  );

  /// A voice talking instead of reading: 24 words, none of them the page's.
  const paraphrase =
      'أهلا بيك يا فندم إحنا هنتكلم مع حضرتك شوية عن الورقة دي '
      'وإيه اللي مكتوب فيها بالتفصيل كده علشان تبقى عارف كل حاجة';

  /// One second of audio in this format.
  const oneSecond = 48000;

  late List<_FakeLiveSession> sessions;
  late List<Result<void, AppFailure>> startResults;
  late _FakeSink sink;
  late _FakeEncoder encoder;
  late _FakeAudioStore store;
  late _FakeDeviceReader device;
  late ReadPaperAloud readPaperAloud;
  late List<VoiceReadEvent> events;
  late StreamSubscription<VoiceReadEvent> subscription;

  setUp(() {
    sessions = [];
    startResults = [];
    sink = _FakeSink();
    encoder = _FakeEncoder();
    store = _FakeAudioStore();
    device = _FakeDeviceReader();
    events = [];

    const normalise = NormaliseArabicForDiff();
    readPaperAloud = ReadPaperAloud(
      openSession: () {
        final session = _FakeLiveSession(
          startResult: sessions.length < startResults.length
              ? startResults[sessions.length]
              : const Ok<void, AppFailure>(null),
        );
        sessions.add(session);
        return session;
      },
      sink: sink,
      encoder: encoder,
      audioStore: store,
      deviceReader: device,
      verify: const VerifyVerbatimRead(normalise),
      align: const AlignSegmentsToAudio(normalise),
    );
  });

  tearDown(() async {
    await subscription.cancel();
    for (final session in sessions) {
      session.dispose();
    }
    await sink.dispose();
    await device.dispose();
  });

  /// Lets the ladder's awaits and the fakes' streams settle.
  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Starts a read and lets it reach the point of waiting for frames.
  Future<void> start({List<VoiceSegment> page = segments}) async {
    subscription = readPaperAloud(
      segments: page,
      audioId: 'paper-1',
    ).listen(events.add);
    await settle();
  }

  /// A whole Live read: three seconds of audio, the transcript, turn complete.
  Future<void> liveReads(_FakeLiveSession session, String transcript) async {
    session.audio(oneSecond);
    await settle();
    session.transcript(transcript);
    await settle();
    session.audio(oneSecond * 2);
    await settle();
    session.complete();
    await settle();
  }

  VoiceReadOutcome outcomeOf(List<VoiceReadEvent> emitted) =>
      emitted.whereType<VoiceReadCompleted>().single.outcome;

  // ── path 1 · Live, as designed ───────────────────────────────────────────

  group('Live tier', () {
    test('reads the paper, resolves spans, and completes verbatim', () async {
      await start();
      await liveReads(sessions.single, perfectTranscript);

      expect(events.first, const VoiceReadStarted(VoiceEngine.geminiLive));
      expect(
        events.whereType<VoiceReadSpansResolved>().single.spans,
        hasLength(3),
      );

      final outcome = outcomeOf(events);
      expect(outcome.engine, VoiceEngine.geminiLive);
      expect(outcome.verified, isTrue);
      expect(outcome.audioSaved, isTrue);
      expect(outcome.duration, const Duration(seconds: 3));
      expect(outcome.spans.map((span) => span.segmentId), [
        'type',
        'amount',
        'risk',
      ]);
      expect(events.whereType<VoiceReadFailed>(), isEmpty);
    });

    test(
      'sends the assembled page, plays it, and saves it encrypted',
      () async {
        await start();
        await liveReads(sessions.single, perfectTranscript);

        expect(sessions.single.turnText, turn.text);
        expect(sink.written, oneSecond * 3);
        expect(encoder.fed, oneSecond * 3);
        expect(store.stored, {'paper-1': encoder.encoded});
      },
    );

    test('releases the speaker and the session on the way out', () async {
      await start();
      await liveReads(sessions.single, perfectTranscript);

      expect(sink.stops, 1);
      expect(sessions.single.cancels, greaterThanOrEqualTo(1));
      expect(encoder.aborts, 0);
      expect(device.reads, 0);
    });

    test('positions carry no segment id before the spans are known', () async {
      await start();
      sessions.single.audio(oneSecond);
      await settle();

      final positions = events.whereType<VoiceReadPositionChanged>();
      expect(positions, isNotEmpty);
      expect(positions.every((event) => event.segmentId == null), isTrue);
    });

    test('maps positions onto segments once the spans are resolved, and waits '
        'for the speaker to finish', () async {
      sink.emitClock = false;
      await start();
      await liveReads(sessions.single, perfectTranscript);

      // The spans are out, the audio is not drained, so the read is still
      // open and nothing has completed.
      expect(events.whereType<VoiceReadSpansResolved>(), hasLength(1));
      expect(events.whereType<VoiceReadCompleted>(), isEmpty);
      expect(sink.stops, 0);

      const heard = Duration(milliseconds: 500);
      sink.tick(heard);
      await settle();
      sink.tick(const Duration(seconds: 3));
      await settle();

      // Which segment covers half a second is T07's arithmetic; what T17 owes
      // is that the position is reported as being inside whichever one it is.
      final spans = events.whereType<VoiceReadSpansResolved>().single.spans;
      expect(
        events.whereType<VoiceReadPositionChanged>().first.segmentId,
        spans.firstWhere((span) => span.contains(heard)).segmentId,
      );
      expect(events.whereType<VoiceReadCompleted>(), hasLength(1));
      expect(sink.stops, 1);
    });
  });

  // ── path 2 + 3 · early abort and the single retry ────────────────────────

  group('early abort', () {
    test('abandons a paraphrasing read and discards its audio', () async {
      await start();
      final abandoned = sessions.single;
      abandoned.audio(oneSecond);
      await settle();
      abandoned.transcript(paraphrase);
      await settle();

      expect(abandoned.cancels, greaterThanOrEqualTo(1));
      expect(encoder.aborts, 1);
      expect(encoder.finishes, 0);
      expect(store.stored, isEmpty);
    });

    test('retries Live exactly once, then reads on the device', () async {
      await start();

      sessions.single.audio(oneSecond);
      await settle();
      sessions.single.transcript(paraphrase);
      await settle();

      expect(sessions, hasLength(2));

      sessions.last.audio(oneSecond);
      await settle();
      sessions.last.transcript(paraphrase);
      await settle();

      expect(sessions, hasLength(2));
      expect(device.reads, 1);
      expect(outcomeOf(events).engine, VoiceEngine.deviceTts);
    });

    test('a retry that reads properly completes on Live', () async {
      await start();

      sessions.single.audio(oneSecond);
      await settle();
      sessions.single.transcript(paraphrase);
      await settle();

      await liveReads(sessions.last, perfectTranscript);

      expect(device.reads, 0);
      expect(
        events.whereType<VoiceReadStarted>().map((event) => event.engine),
        [VoiceEngine.geminiLive, VoiceEngine.geminiLive],
      );
      expect(outcomeOf(events).verified, isTrue);
    });
  });

  // ── path 4 · the device's own engine ─────────────────────────────────────

  group('falling to the device', () {
    test('a session that will not start is not retried', () async {
      startResults = [const Err(VoiceServiceFailure())];
      await start();

      expect(sessions, hasLength(1));
      expect(device.reads, 1);
      expect(
        events.whereType<VoiceReadStarted>().single.engine,
        VoiceEngine.deviceTts,
      );
    });

    test('a speaker that will not open costs no session at all', () async {
      sink.openResult = const Err(AudioPlaybackFailure());
      await start();

      expect(sessions.single.startCalls, 0);
      expect(sessions.single.cancels, greaterThanOrEqualTo(1));
      expect(device.reads, 1);
    });

    test('a drop after two seconds goes to the device, not a retry', () async {
      await start();
      sessions.single.audio(oneSecond * 3);
      await settle();
      sessions.single.lose(
        const VoiceStreamInterruptedFailure(Duration(seconds: 3)),
      );
      await settle();

      expect(sessions, hasLength(1));
      expect(encoder.aborts, 1);
      expect(store.stored, isEmpty);
      expect(device.reads, 1);
    });

    test('a drop in the first two seconds restarts Live once', () async {
      await start();
      sessions.single.audio(oneSecond);
      await settle();
      sessions.single.lose(
        const VoiceStreamInterruptedFailure(Duration(milliseconds: 900)),
      );
      await settle();

      expect(sessions, hasLength(2));
      expect(device.reads, 0);
    });

    test('a stream that ends without saying how goes to the device', () async {
      await start();
      sessions.single.audio(oneSecond);
      await settle();
      await sessions.single.closeSilently();
      await settle();

      expect(encoder.aborts, 1);
      expect(device.reads, 1);
    });

    test(
      'the device read is verbatim, saves nothing, and keeps its spans',
      () async {
        device.spans = const [
          SpokenCardSpan(
            segmentId: 'type',
            start: Duration.zero,
            end: Duration(seconds: 4),
            exact: false,
          ),
        ];
        startResults = [const Err(VoiceServiceFailure())];
        await start();

        final outcome = outcomeOf(events);
        expect(outcome.engine, VoiceEngine.deviceTts);
        expect(outcome.verified, isTrue);
        expect(outcome.audioSaved, isFalse);
        expect(outcome.duration, const Duration(seconds: 30));
        expect(outcome.spans.single.segmentId, 'type');
        expect(device.turn?.text, turn.text);
      },
    );
  });

  // ── path 5 · nothing left ────────────────────────────────────────────────

  group('nothing can read it', () {
    test('a device with no Arabic voice reports that failure intact', () async {
      startResults = [const Err(VoiceServiceFailure())];
      device.result = const Err(NoArabicVoiceFailure());
      await start();

      expect(
        events.whereType<VoiceReadFailed>().single.failure,
        const NoArabicVoiceFailure(),
      );
      expect(events.whereType<VoiceReadCompleted>(), isEmpty);
    });

    test('the user is told once, after every tier is spent', () async {
      device.result = const Err(TtsFailure());
      await start();

      sessions.single.audio(oneSecond);
      await settle();
      sessions.single.transcript(paraphrase);
      await settle();
      sessions.last.audio(oneSecond);
      await settle();
      sessions.last.transcript(paraphrase);
      await settle();

      expect(events.whereType<VoiceReadFailed>(), hasLength(1));
    });
  });

  // ── the late mismatch, and what is saved anyway ──────────────────────────

  group('verdicts on a finished read', () {
    test('a divergence found at the end keeps the audio, unverified', () async {
      await start();
      sessions.single.audio(oneSecond * 3);
      await settle();
      sessions.single.transcript(lateMismatchTranscript);
      await settle();
      sessions.single.complete();
      await settle();

      final outcome = outcomeOf(events);
      expect(outcome.verified, isFalse);
      expect(outcome.audioSaved, isTrue);
      expect(store.stored, hasLength(1));
      expect(sessions, hasLength(1));
      expect(device.reads, 0);
    });

    test('an encoder that never began still lets the paper be read', () async {
      encoder.beginResult = const Err(AudioEncodingFailure());
      await start();
      await liveReads(sessions.single, perfectTranscript);

      final outcome = outcomeOf(events);
      expect(outcome.audioSaved, isFalse);
      expect(outcome.verified, isTrue);
      expect(encoder.fed, 0);
      expect(encoder.finishes, 0);
      expect(store.stored, isEmpty);
    });

    test('an encoder that fails at the end loses only the replay', () async {
      encoder.finishResult = const Err(AudioEncodingFailure());
      await start();
      await liveReads(sessions.single, perfectTranscript);

      expect(outcomeOf(events).audioSaved, isFalse);
      expect(store.stored, isEmpty);
      expect(events.whereType<VoiceReadFailed>(), isEmpty);
    });

    test('a store that refuses the file loses only the replay', () async {
      store.storeResult = const Err(FileStorageFailure());
      await start();
      await liveReads(sessions.single, perfectTranscript);

      expect(outcomeOf(events).audioSaved, isFalse);
      expect(events.whereType<VoiceReadCompleted>(), hasLength(1));
    });
  });

  // ── the edges ────────────────────────────────────────────────────────────

  group('edges', () {
    test('an empty page is refused without touching an engine', () async {
      await start(page: const []);

      expect(events.single, const VoiceReadFailed(TtsFailure()));
      expect(sessions, isEmpty);
      expect(sink.opens, 0);
      expect(device.reads, 0);
    });

    test('a page of blank segments is refused the same way', () async {
      await start(
        page: const [VoiceSegment(id: 'blank', text: '   ')],
      );

      expect(events.single, const VoiceReadFailed(TtsFailure()));
      expect(sessions, isEmpty);
    });

    test(
      'a speaker that throws instead of reporting is still a read',
      () async {
        // T13's `write` reports a dead platform channel by throwing, not with a
        // `Result` — a phone with no audio host must still hear its paper.
        sink.throwOnWrite = true;
        await start();
        sessions.single.audio(oneSecond);
        await settle();

        expect(encoder.aborts, 1);
        expect(sink.stops, 1);
        expect(device.reads, 1);
        expect(outcomeOf(events).engine, VoiceEngine.deviceTts);
      },
    );

    test('a paper the user heard is never reported as failed', () async {
      // Cleanup runs after the read is already decided. A speaker that throws
      // on its way out must not skip the session cancel behind it, nor turn a
      // paper the user heard into a read the screen says failed.
      sink.throwOnStop = true;
      await start();
      await liveReads(sessions.single, perfectTranscript);

      expect(events.whereType<VoiceReadFailed>(), isEmpty);
      expect(outcomeOf(events).engine, VoiceEngine.geminiLive);
      expect(outcomeOf(events).audioSaved, isTrue);
      expect(sessions.single.cancels, greaterThanOrEqualTo(1));
      expect(device.reads, 0);
    });

    test('leaving the screen stops the voice and frees the session', () async {
      await start();
      final live = sessions.single;
      live.audio(oneSecond);
      await settle();

      await subscription.cancel();
      await settle();

      expect(live.cancels, greaterThanOrEqualTo(1));
      expect(sink.stops, 1);
      expect(encoder.aborts, 1);
      expect(device.stops, 1);
      // The ladder does not quietly carry on to the next tier for a listener
      // who has gone.
      expect(device.reads, 0);
      expect(sessions, hasLength(1));
      expect(store.stored, isEmpty);
    });

    test('no event describes the page in words (CLAUDE.md §7)', () async {
      await start();
      await liveReads(sessions.single, perfectTranscript);

      for (final event in events) {
        expect(event.toString(), isNot(contains('فاتورة')));
        expect(event.toString(), isNot(contains('نوفمبر')));
      }
    });
  });
}

final class _FakeLiveSession implements LiveVoiceSession {
  _FakeLiveSession({required this.startResult});

  final Result<void, AppFailure> startResult;
  final _events = StreamController<LiveVoiceEvent>();

  var startCalls = 0;
  var cancels = 0;
  String? turnText;

  @override
  PcmFormat get format => PcmFormat.geminiLive;

  @override
  Stream<LiveVoiceEvent> get events => _events.stream;

  @override
  Future<Result<void, AppFailure>> start(String turnText) async {
    startCalls++;
    this.turnText = turnText;
    return startResult;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    // Not awaited: a non-broadcast controller's `close()` does not complete
    // until its stream has been listened to, and a session cancelled before
    // the ladder ever subscribed — an unopenable speaker, a refused `start` —
    // would otherwise hang the read instead of falling to the next tier.
    _closeWithoutWaiting();
  }

  void audio(int byteCount) {
    if (!_events.isClosed) _events.add(LivePcmChunk(Uint8List(byteCount)));
  }

  void transcript(String text) {
    if (!_events.isClosed) _events.add(LiveTranscriptDelta(text));
  }

  void complete() {
    if (!_events.isClosed) _events.add(const LiveTurnComplete());
  }

  void lose(AppFailure failure) {
    if (!_events.isClosed) _events.add(LiveSessionLost(failure));
  }

  /// The socket going away with nothing said about how the turn ended.
  ///
  /// Awaited here because the ladder is subscribed by the time a test calls it.
  Future<void> closeSilently() async {
    if (!_events.isClosed) await _events.close();
  }

  void _closeWithoutWaiting() {
    if (!_events.isClosed) unawaited(_events.close());
  }

  void dispose() => _closeWithoutWaiting();
}

/// Stands in for the `MissingPluginException` a phone with no audio host
/// raises, without dragging `services.dart` into a domain test.
final class _NoAudioHost implements Exception {
  const _NoAudioHost();
}

final class _FakeSink implements PcmAudioSink {
  final _positions = StreamController<Duration>.broadcast(sync: true);

  Result<void, AppFailure> openResult = const Ok(null);

  /// Whether a write advances the playback clock, as a real speaker would.
  bool emitClock = true;

  /// A dead platform channel: `write` reports by throwing (T13).
  bool throwOnWrite = false;

  /// A sink that fails on the way out, after the paper has been heard.
  bool throwOnStop = false;

  var opens = 0;
  var stops = 0;
  var written = 0;
  var played = Duration.zero;

  @override
  Future<Result<void, AppFailure>> open(PcmFormat format) async {
    opens++;
    return openResult;
  }

  @override
  Future<void> write(Uint8List chunk) async {
    if (throwOnWrite) throw const _NoAudioHost();
    written += chunk.length;
    if (emitClock) tick(PcmFormat.geminiLive.durationOfBytes(written));
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<Duration> stop() async {
    stops++;
    if (throwOnStop) throw const _NoAudioHost();
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
  Result<Uint8List, AppFailure>? finishResult;

  final encoded = Uint8List.fromList(const [1, 2, 3, 4]);

  var begins = 0;
  var finishes = 0;
  var aborts = 0;
  var fed = 0;

  @override
  Future<Result<void, AppFailure>> begin(PcmFormat format) async {
    begins++;
    return beginResult;
  }

  @override
  Future<void> feed(Uint8List chunk) async {
    fed += chunk.length;
  }

  @override
  Future<Result<Uint8List, AppFailure>> finish() async {
    finishes++;
    return finishResult ?? Ok(encoded);
  }

  @override
  Future<void> abort() async {
    aborts++;
  }
}

final class _FakeAudioStore implements EncryptedAudioStore {
  final stored = <String, Uint8List>{};

  Result<String, AppFailure> storeResult = const Ok('/audio/paper-1.enc');

  @override
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  }) async {
    if (storeResult.isOk) stored[id] = audioBytes;
    return storeResult;
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async =>
      const Err(FileStorageFailure());

  @override
  Future<void> delete(String id) async => stored.remove(id);

  @override
  Future<void> deleteAll() async => stored.clear();

  @override
  Future<bool> exists(String id) async => stored.containsKey(id);
}

final class _FakeDeviceReader implements DeviceVoiceReader {
  final _events = StreamController<VoiceReadEvent>.broadcast(sync: true);

  Result<Duration, AppFailure> result = const Ok(Duration(seconds: 30));
  List<SpokenCardSpan> spans = const [];

  var reads = 0;
  var stops = 0;
  VoiceTurnText? turn;

  @override
  Stream<VoiceReadEvent> get events => _events.stream;

  @override
  Future<Result<Duration, AppFailure>> read(VoiceTurnText turn) async {
    reads++;
    this.turn = turn;
    if (spans.isNotEmpty) _events.add(VoiceReadSpansResolved(spans));
    return result;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  Future<void> dispose() => _events.close();
}
