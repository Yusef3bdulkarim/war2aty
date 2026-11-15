import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_error_code.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_event.dart';
import 'package:war2aty/features/audio_reader/domain/services/reading_queue.dart';
import 'package:war2aty/features/voice/data/services/reading_queue_voice_reader.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_event.dart';
import 'package:war2aty/features/voice/domain/entities/voice_segment.dart';
import 'package:war2aty/features/voice/domain/usecases/build_voice_turn_text.dart';

import '../../../../support/fakes.dart';

const _arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
const _englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');

/// A page in the shape F38 will hand the spine: three cards, Arabic, in the
/// order the screen reads them.
const _segments = [
  VoiceSegment(id: 'kind', text: 'دي فاتورة كهربا'),
  VoiceSegment(id: 'amount', text: 'المبلغ 250 جنيه'),
  VoiceSegment(id: 'deadline', text: 'آخر ميعاد 20 نوفمبر'),
];

void main() {
  late FakeTextToSpeechService tts;
  late ReadingQueue queue;
  late ReadingQueueVoiceReader reader;
  late List<VoiceReadEvent> events;
  late DateTime now;

  /// The turn the ladder would build, and the one every assertion here is
  /// measured in: the engine speaks it, so its character offsets are what the
  /// progress events carry.
  late VoiceTurnText turn;

  setUp(() {
    tts = FakeTextToSpeechService(voices: [_arabicVoice, _englishVoice]);
    queue = readingQueueOver(tts);
    now = DateTime.utc(2026, 11, 14, 10);
    reader = ReadingQueueVoiceReader(queue, clock: () => now);
    events = [];
    final subscription = reader.events.listen(events.add);
    addTearDown(subscription.cancel);
    turn = const BuildVoiceTurnText()(_segments);
  });

  tearDown(() => tts.dispose());

  /// Lets a broadcast engine event reach the queue, and the queue's own event
  /// reach the reader. No real delays (F37 "Testing").
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void advance(Duration by) => now = now.add(by);

  Future<void> emit(TtsEvent event) async {
    tts.emitEvent(event);
    await settle();
  }

  /// Starts a read and lets the queue hand the first utterance over, without
  /// awaiting the read itself — which only answers when the reading has ended.
  Future<Future<Result<Duration, AppFailure>>> beginRead() async {
    final pending = reader.read(turn);
    await settle();
    return pending;
  }

  List<VoiceReadPositionChanged> positions() =>
      events.whereType<VoiceReadPositionChanged>().toList();

  List<SpokenCardSpan> resolvedSpans() =>
      events.whereType<VoiceReadSpansResolved>().single.spans;

  group('ReadingQueueVoiceReader · the read', () {
    test('speaks the turn text as the ladder built it', () async {
      await beginRead();

      expect(tts.spoken, [turn.text]);
    });

    test(
      'does not answer when the engine has merely taken the paper',
      () async {
        final pending = await beginRead();
        var answered = false;
        unawaited(pending.then((_) => answered = true));

        await emit(const TtsStarted());
        advance(const Duration(seconds: 30));
        await settle();

        expect(answered, isFalse);
      },
    );

    test('answers with how long the reading lasted', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      advance(const Duration(seconds: 42));
      await emit(const TtsCompleted());

      expect(
        await pending,
        const Ok<Duration, AppFailure>(Duration(seconds: 42)),
      );
    });

    test('measures from the moment the engine began speaking', () async {
      final pending = await beginRead();
      // The engine took a second to start — which the user did not hear.
      advance(const Duration(seconds: 1));
      await emit(const TtsStarted());
      advance(const Duration(seconds: 10));
      await emit(const TtsCompleted());

      expect(
        await pending,
        const Ok<Duration, AppFailure>(Duration(seconds: 10)),
      );
    });

    test(
      'takes a continue for a start, as Android reports after a pause',
      () async {
        final pending = await beginRead();
        await emit(const TtsContinued());
        advance(const Duration(seconds: 8));
        await emit(const TtsCompleted());

        expect(
          await pending,
          const Ok<Duration, AppFailure>(Duration(seconds: 8)),
        );
        expect(positions().first.position, Duration.zero);
      },
    );

    test(
      'still answers for an engine that completes without a start',
      () async {
        final pending = await beginRead();
        advance(const Duration(seconds: 5));
        await emit(const TtsCompleted());

        expect(
          await pending,
          const Ok<Duration, AppFailure>(Duration(seconds: 5)),
        );
      },
    );
  });

  group('ReadingQueueVoiceReader · positions', () {
    test('puts the highlight on the first card the moment it starts', () async {
      await beginRead();
      await emit(const TtsStarted());

      expect(positions(), [
        const VoiceReadPositionChanged(
          position: Duration.zero,
          segmentId: 'kind',
        ),
      ]);
    });

    test(
      'maps the engine\'s character offsets to the card being spoken',
      () async {
        await beginRead();
        await emit(const TtsStarted());

        final amount = turn.offsets[1];
        advance(const Duration(seconds: 5));
        await emit(
          TtsProgressed(start: amount.start + 2, end: amount.start + 8),
        );

        expect(
          positions().last,
          const VoiceReadPositionChanged(
            position: Duration(seconds: 5),
            segmentId: 'amount',
          ),
        );
      },
    );

    test('reports no card inside the separator between two of them', () async {
      await beginRead();
      await emit(const TtsStarted());

      // The full stop and blank line T06 inserts: spoken time that belongs to
      // no card, where the screen holds the highlight it has.
      final between = turn.offsets[0].end;
      advance(const Duration(seconds: 3));
      await emit(TtsProgressed(start: between, end: between + 1));

      expect(positions().last.segmentId, isNull);
      expect(positions().last.position, const Duration(seconds: 3));
    });

    test('uses the app\'s clock, not the engine, for the position', () async {
      await beginRead();
      await emit(const TtsStarted());

      advance(const Duration(milliseconds: 1500));
      await emit(const TtsProgressed(start: 1, end: 3));
      advance(const Duration(milliseconds: 2500));
      await emit(const TtsProgressed(start: 4, end: 9));

      expect(positions().map((event) => event.position), const [
        Duration.zero,
        Duration(milliseconds: 1500),
        Duration(seconds: 4),
      ]);
    });

    test('reports nothing before the reading has begun', () async {
      await beginRead();

      await emit(const TtsProgressed(start: 4, end: 9));

      expect(positions(), isEmpty);
    });

    test(
      'maps offsets the queue moved into the reading\'s own coordinates',
      () async {
        // An English word on a device with no English voice: the queue speaks it
        // transliterated, in its own utterance, and shifts the engine's
        // per-utterance offsets into the reading's. What arrives here is already
        // in turn-text coordinates, which is the only reason this adapter can
        // index `turn.offsets` with them at all.
        tts.voices = [_arabicVoice];
        const segments = [
          VoiceSegment(id: 'kind', text: 'دي فاتورة'),
          VoiceSegment(id: 'ref', text: 'رقم invoice 44'),
        ];
        turn = const BuildVoiceTurnText()(segments);

        await beginRead();
        await emit(const TtsStarted());
        // The queue speaks one run at a time and moves on when the engine says
        // the current one finished — a completion mid-reading, which it keeps
        // to itself.
        await emit(const TtsCompleted());
        expect(tts.spoken.length, greaterThan(1));

        // The second utterance, from its own first character. The engine counts
        // that as 0; the reading is further along than that.
        advance(const Duration(seconds: 4));
        await emit(const TtsProgressed(start: 0, end: 2));

        expect(positions().last.segmentId, 'ref');
        expect(positions().last.position, const Duration(seconds: 4));
      },
    );
  });

  group('ReadingQueueVoiceReader · spans', () {
    test(
      'places every card, and the spans partition the whole reading',
      () async {
        final pending = await beginRead();
        await emit(const TtsStarted());
        advance(const Duration(seconds: 4));
        await emit(TtsProgressed(start: turn.offsets[1].start, end: 33));
        advance(const Duration(seconds: 6));
        await emit(const TtsCompleted());
        await pending;

        final spans = resolvedSpans();
        expect(spans.map((span) => span.segmentId), [
          'kind',
          'amount',
          'deadline',
        ]);
        expect(spans.first.start, Duration.zero);
        expect(spans.last.end, const Duration(seconds: 10));
        for (var i = 0; i < spans.length - 1; i++) {
          expect(spans[i].end, spans[i + 1].start);
        }
      },
    );

    test(
      'measures the card a word boundary landed in, interpolates the rest',
      () async {
        final pending = await beginRead();
        await emit(const TtsStarted());
        advance(const Duration(seconds: 4));
        await emit(TtsProgressed(start: turn.offsets[1].start, end: 33));
        advance(const Duration(seconds: 6));
        await emit(const TtsCompleted());
        await pending;

        final spans = resolvedSpans();
        expect(spans[1].start, const Duration(seconds: 4));
        expect(spans[1].exact, isTrue);
        expect(spans[0].exact, isFalse);
        expect(spans[2].exact, isFalse);
        // 18 chars measured at 4s, 55 in all by 10s: the third card is placed
        // between that boundary and the end of the reading by its characters.
        expect(spans[2].start, const Duration(microseconds: 6918918));
      },
    );

    test(
      'falls back to each card\'s share of the page with no boundaries',
      () async {
        final pending = await beginRead();
        await emit(const TtsStarted());
        advance(const Duration(seconds: 10));
        await emit(const TtsCompleted());
        await pending;

        final spans = resolvedSpans();
        expect(spans.every((span) => span.exact), isFalse);
        expect(spans[0].start, Duration.zero);
        expect(spans[1].start, const Duration(microseconds: 3272727));
        expect(spans[2].start, const Duration(microseconds: 6545454));
      },
    );

    test('resolves them before the read answers, while the ladder is still '
        'listening', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      var spansSeenBeforeTheAnswer = false;
      unawaited(
        pending.then(
          (_) => spansSeenBeforeTheAnswer = events.any(
            (event) => event is VoiceReadSpansResolved,
          ),
        ),
      );

      advance(const Duration(seconds: 9));
      await emit(const TtsCompleted());
      await pending;
      await settle();

      expect(spansSeenBeforeTheAnswer, isTrue);
    });

    test('resolves nothing at all for a reading that failed', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      await emit(const TtsFailed(code: TtsErrorCode.synthesis));
      await pending;

      expect(events.whereType<VoiceReadSpansResolved>(), isEmpty);
    });
  });

  group('ReadingQueueVoiceReader · failures', () {
    test('passes a missing Arabic voice through for the screen to offer '
        'settings', () async {
      tts.voices = [_englishVoice];

      expect(
        await reader.read(turn),
        const Err<Duration, AppFailure>(NoArabicVoiceFailure()),
      );
    });

    test('reports an engine that would not take the paper', () async {
      tts.speakFails = true;

      expect(
        await reader.read(turn),
        const Err<Duration, AppFailure>(TtsFailure()),
      );
    });

    test('reports nothing to say', () async {
      turn = const BuildVoiceTurnText()(const []);

      expect(
        await reader.read(turn),
        const Err<Duration, AppFailure>(TtsFailure()),
      );
      expect(tts.spoken, isEmpty);
      expect(events, isEmpty);
    });

    test('reports a failure the queue did not absorb', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      await emit(const TtsFailed(code: TtsErrorCode.synthesis));

      expect(await pending, const Err<Duration, AppFailure>(TtsFailure()));
    });

    test(
      'is not told about a passing error the queue retried in silence',
      () async {
        // A voice whose data is still downloading (F30-T16, RC-2). The queue
        // speaks the same run again without a word to anyone, and the whole
        // reason this tier reuses it is that the ladder never has to know.
        final pending = await beginRead();
        await emit(const TtsStarted());
        await emit(const TtsFailed(code: TtsErrorCode.notInstalledYet));

        expect(events.whereType<VoiceReadSpansResolved>(), isEmpty);
        expect(tts.spoken.length, 2);

        advance(const Duration(seconds: 9));
        await emit(const TtsCompleted());

        expect(
          await pending,
          const Ok<Duration, AppFailure>(Duration(seconds: 9)),
        );
      },
    );

    test('gives the paper up when something else takes the engine', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      // The Settings voice preview is the one thing outside the queue that
      // speaks; the runs behind it are never going to be read.
      await emit(const TtsCancelled());

      expect(await pending, const Err<Duration, AppFailure>(TtsFailure()));
    });

    test(
      'ignores the cancel of the utterance this reading just flushed',
      () async {
        final pending = await beginRead();
        // Arrives after this reading is installed and before it starts speaking:
        // acting on it would fail a paper that is about to be read perfectly
        // well.
        await emit(const TtsCancelled());
        await emit(const TtsStarted());
        advance(const Duration(seconds: 7));
        await emit(const TtsCompleted());

        expect(
          await pending,
          const Ok<Duration, AppFailure>(Duration(seconds: 7)),
        );
      },
    );

    test('answers once, however many terminal events arrive', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      advance(const Duration(seconds: 7));
      await emit(const TtsCompleted());
      await emit(const TtsCancelled());
      await emit(const TtsFailed(code: TtsErrorCode.synthesis));

      expect(
        await pending,
        const Ok<Duration, AppFailure>(Duration(seconds: 7)),
      );
      expect(events.whereType<VoiceReadSpansResolved>().length, 1);
    });

    test('supersedes a read that is replaced by another', () async {
      final first = await beginRead();
      final second = await beginRead();
      await emit(const TtsStarted());
      advance(const Duration(seconds: 3));
      await emit(const TtsCompleted());

      expect(await first, const Err<Duration, AppFailure>(TtsFailure()));
      expect(
        await second,
        const Ok<Duration, AppFailure>(Duration(seconds: 3)),
      );
    });

    test('is not thrown off by a pause from somewhere else', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      await emit(const TtsPaused());
      advance(const Duration(seconds: 6));
      await emit(const TtsCompleted());

      expect(
        await pending,
        const Ok<Duration, AppFailure>(Duration(seconds: 6)),
      );
    });
  });

  group('ReadingQueueVoiceReader · stopping', () {
    test('silences the engine and answers with what was read', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      advance(const Duration(seconds: 12));

      await reader.stop();

      expect(
        await pending,
        const Ok<Duration, AppFailure>(Duration(seconds: 12)),
      );
      expect(tts.stopCount, 1);
    });

    test(
      'leaves a shared engine alone when nothing of ours is reading',
      () async {
        // `ReadPaperAloud` stops this tier on every cancel, including one where
        // Live was the tier that read.
        await reader.stop();

        expect(tts.stopCount, 0);
      },
    );

    test('leaves the engine alone after the reading already ended', () async {
      final pending = await beginRead();
      await emit(const TtsStarted());
      await emit(const TtsCompleted());
      await pending;

      await reader.stop();

      expect(tts.stopCount, 0);
    });
  });

  group('ReadingQueueVoiceReader · privacy', () {
    test(
      'no event it emits carries a word of the page (CLAUDE.md §7)',
      () async {
        final pending = await beginRead();
        await emit(const TtsStarted());
        advance(const Duration(seconds: 2));
        await emit(TtsProgressed(start: turn.offsets[1].start, end: 33));
        advance(const Duration(seconds: 4));
        await emit(const TtsCompleted());
        await pending;

        expect(events, isNotEmpty);
        for (final event in events) {
          for (final word in const ['فاتورة', 'كهربا', '250', 'نوفمبر', '20']) {
            expect(event.toString(), isNot(contains(word)));
          }
        }
        for (final span in resolvedSpans()) {
          expect(span.toString(), isNot(contains('فاتورة')));
        }
      },
    );
  });
}
