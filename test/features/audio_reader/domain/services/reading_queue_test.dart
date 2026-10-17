import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_event.dart';
import 'package:war2aty/features/audio_reader/domain/services/reading_queue.dart';

import '../../../../support/fakes.dart';

const _arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
const _englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');

/// A reading that is Arabic, then English, then Arabic again — the shape the
/// owner's paper had (F30 RC-4). Its runs are below, in order.
const _mixed = 'فاتورة invoice لازم تتدفع';
const _mixedRuns = ['فاتورة', ' invoice', ' لازم تتدفع'];

void main() {
  late FakeTextToSpeechService tts;
  late ReadingQueue queue;
  late List<TtsEvent> events;

  setUp(() {
    tts = FakeTextToSpeechService(voices: [_arabicVoice, _englishVoice]);
    queue = readingQueueOver(tts);
    events = [];
    final subscription = queue.events.listen(events.add);
    addTearDown(subscription.cancel);
  });

  tearDown(() => tts.dispose());

  /// Lets a broadcast event reach the queue and the queue's own
  /// `setVoice`/`speak` round trip for the next run finish.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// What the engine does when it finishes an utterance.
  Future<void> completeUtterance() async {
    tts.emitEvent(const TtsCompleted());
    await settle();
  }

  group('ReadingQueue · one language', () {
    test('speaks a wholly Arabic reading as a single utterance', () async {
      final outcome = await queue.speak('فاتورة كهرباء لازم تتدفع');

      expect(outcome, const Ok<int, AppFailure>(24));
      expect(tts.spoken, const ['فاتورة كهرباء لازم تتدفع']);
      expect(tts.voicesSet, const [_arabicVoice]);
    });

    test(
      'answers with the whole reading\'s length, not the first run\'s',
      () async {
        final outcome = await queue.speak(_mixed);

        expect(outcome, const Ok<int, AppFailure>(_mixed.length));
      },
    );

    test('refuses a reading with nothing to say, and speaks nothing', () async {
      expect(await queue.speak(''), const Err<int, AppFailure>(TtsFailure()));
      expect(
        await queue.speak('   \n '),
        const Err<int, AppFailure>(TtsFailure()),
      );
      expect(tts.spoken, isEmpty);
    });

    test('reports the engine refusing the first utterance', () async {
      tts.speakFails = true;

      final outcome = await queue.speak('فاتورة كهرباء');

      expect(outcome, const Err<int, AppFailure>(TtsFailure()));
    });
  });

  group('ReadingQueue · the queue', () {
    test(
      'speaks only the first run until the engine says it finished',
      () async {
        await queue.speak(_mixed);

        expect(tts.spoken, [_mixedRuns.first]);

        await completeUtterance();
        expect(tts.spoken, _mixedRuns.take(2));

        await completeUtterance();
        expect(tts.spoken, _mixedRuns);
      },
    );

    test('switches to each run\'s own voice as it reaches it', () async {
      await queue.speak(_mixed);
      await completeUtterance();
      await completeUtterance();

      // The owner's symptom in one assertion: the English run is no longer
      // handed to the Arabic voice that read the words around it.
      expect(tts.voicesSet, const [_arabicVoice, _englishVoice, _arabicVoice]);
    });

    test('keeps a run finishing mid-reading to itself', () async {
      await queue.speak(_mixed);
      await completeUtterance();
      await completeUtterance();

      expect(events.whereType<TtsCompleted>(), isEmpty);
    });

    test('reports the last run finishing as the reading finishing', () async {
      await queue.speak(_mixed);
      await completeUtterance();
      await completeUtterance();
      await completeUtterance();

      expect(events.whereType<TtsCompleted>(), const [TtsCompleted()]);
      // And nothing more was spoken for it.
      expect(tts.spoken, _mixedRuns);
    });

    test(
      'reports only the first run starting as the reading starting',
      () async {
        await queue.speak(_mixed);
        tts.emitEvent(const TtsStarted());
        await settle();
        await completeUtterance();
        tts.emitEvent(const TtsStarted());
        await settle();

        expect(events.whereType<TtsStarted>(), const [TtsStarted()]);
      },
    );

    test(
      'surfaces a run the engine refuses part-way through the queue',
      () async {
        await queue.speak(_mixed);
        tts.speakFails = true;
        await completeUtterance();

        expect(events.whereType<TtsFailed>(), const [TtsFailed()]);
        // And the queue is abandoned rather than carrying on past it.
        tts.speakFails = false;
        await completeUtterance();
        expect(tts.spoken, _mixedRuns.take(2));
      },
    );
  });

  group('ReadingQueue · progress across the queue', () {
    test('moves an utterance\'s offsets into the whole reading\'s', () async {
      await queue.speak(_mixed);

      // Inside the first run, the engine's offsets are the reading's.
      tts.emitEvent(const TtsProgressed(start: 0, end: 6));
      await settle();
      expect(events.whereType<TtsProgressed>(), const [
        TtsProgressed(start: 0, end: 6),
      ]);

      await completeUtterance();
      // The second run starts 6 code units in, and the engine counts from
      // zero again — so without the shift this would read as the bar
      // jumping back to the start of the paper.
      tts.emitEvent(const TtsProgressed(start: 1, end: 8));
      await settle();
      expect(
        events.whereType<TtsProgressed>().last,
        const TtsProgressed(start: 7, end: 14),
      );
    });

    test('the last run\'s progress reaches the end of the reading', () async {
      await queue.speak(_mixed);
      await completeUtterance();
      await completeUtterance();

      final lastRun = _mixedRuns.last;
      tts.emitEvent(
        TtsProgressed(start: lastRun.length - 1, end: lastRun.length),
      );
      await settle();

      expect(
        events.whereType<TtsProgressed>().last,
        const TtsProgressed(start: _mixed.length - 1, end: _mixed.length),
      );
    });
  });

  group('ReadingQueue · being interrupted', () {
    test('stop drops the runs it had not reached', () async {
      await queue.speak(_mixed);

      final outcome = await queue.stop();

      expect(outcome, const Ok<void, AppFailure>(null));
      expect(tts.stopCount, 1);
      // The gap between two runs is the dangerous moment: the engine has
      // nothing to silence, so only dropping the queue keeps the next run
      // from starting on its own.
      await completeUtterance();
      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('a new reading replaces the one that was queued', () async {
      await queue.speak(_mixed);
      await queue.speak('فاتورة تانية');

      expect(tts.spoken, [_mixedRuns.first, 'فاتورة تانية']);

      await completeUtterance();
      // The second reading was one run, so its completion ends it — none of
      // the first reading's remaining runs may follow.
      expect(tts.spoken, [_mixedRuns.first, 'فاتورة تانية']);
      expect(events.whereType<TtsCompleted>(), const [TtsCompleted()]);
    });

    test('the cancel a new reading causes does not drop its queue', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsStarted());
      await settle();

      // Starting a second reading flushes the first utterance, and the
      // engine reports that as a cancel — which arrives once the new
      // reading is already installed.
      await queue.speak(_mixed);
      tts.emitEvent(const TtsCancelled());
      await settle();

      await completeUtterance();
      expect(tts.spoken, [
        _mixedRuns.first,
        _mixedRuns.first,
        _mixedRuns.elementAt(1),
      ]);
    });

    test(
      'a cancel that interrupts a run the engine had started drops it',
      () async {
        await queue.speak(_mixed);
        tts.emitEvent(const TtsStarted());
        await settle();

        // Something outside the queue took the engine — the voice preview in
        // Settings is the one thing that can.
        tts.emitEvent(const TtsCancelled());
        await settle();
        await completeUtterance();

        expect(tts.spoken, [_mixedRuns.first]);
      },
    );

    test(
      'an engine failure ends the reading rather than queueing on',
      () async {
        await queue.speak(_mixed);
        tts.emitEvent(const TtsFailed());
        await settle();
        await completeUtterance();

        expect(tts.spoken, [_mixedRuns.first]);
        expect(events.whereType<TtsFailed>(), const [TtsFailed()]);
      },
    );
  });

  group('ReadingQueue · a device missing a voice', () {
    test(
      'refuses a mostly-Arabic reading when no Arabic voice exists',
      () async {
        tts.voices = [_englishVoice];

        final outcome = await queue.speak(_mixed);

        expect(outcome, const Err<int, AppFailure>(NoArabicVoiceFailure()));
        expect(tts.spoken, isEmpty);
      },
    );

    test(
      'reads a mostly-English paper anyway when no Arabic voice exists',
      () async {
        // The reason the refusal is decided on the whole reading and not per
        // run: one Arabic word is not worth refusing an English paper over.
        tts.voices = [_englishVoice];

        final outcome = await queue.speak('Pay مصر before Friday');

        expect(outcome, const Ok<int, AppFailure>(21));
        expect(tts.spoken, const ['Pay']);
      },
    );

    test(
      'reads a run it has no voice for with whatever the engine has',
      () async {
        // No English voice: the English run is still spoken rather than
        // dropped, just not switched to — F30-T17's transliteration is what
        // makes it intelligible.
        tts.voices = [_arabicVoice];

        await queue.speak(_mixed);
        await completeUtterance();

        expect(tts.spoken, _mixedRuns.take(2));
        expect(tts.voicesSet, const [_arabicVoice]);
      },
    );

    test('reads on when the device reports no voices at all', () async {
      // Android answers with an empty list while its engine is still
      // binding, which is not evidence that a voice is missing.
      tts.voices = const [];

      final outcome = await queue.speak(_mixed);

      expect(outcome, const Ok<int, AppFailure>(_mixed.length));
      expect(tts.spoken, [_mixedRuns.first]);
      expect(tts.voicesSet, isEmpty);
    });

    test('reads on when the device cannot be asked for its voices', () async {
      tts.getVoicesFails = true;

      final outcome = await queue.speak(_mixed);

      expect(outcome, const Ok<int, AppFailure>(_mixed.length));
      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('asks for the voices once per reading, not once per run', () async {
      await queue.speak(_mixed);
      await completeUtterance();
      await completeUtterance();

      expect(tts.spoken, _mixedRuns);
      expect(tts.getVoicesCount, 1);
    });
  });
}
