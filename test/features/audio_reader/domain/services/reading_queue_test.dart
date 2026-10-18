import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_error_code.dart';
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

    test(
      'a resume inside a run keeps counting from that run\'s start',
      () async {
        await queue.speak(_mixed);
        await completeUtterance();

        // Paused partway through the second run, then resumed. Android hands
        // back a fresh utterance covering only the run's unread remainder, so
        // the engine counts from zero again — but the run still begins where
        // it began, and shifting by zero instead would put the bar back at
        // the top of the paper (F30-T13).
        tts.emitEvent(const TtsProgressed(start: 0, end: 5));
        await settle();
        await queue.pause();
        await queue.resume();
        tts.emitEvent(const TtsProgressed(start: 0, end: 1));
        await settle();

        const secondRunStart = 6;
        expect(
          events.whereType<TtsProgressed>().last,
          const TtsProgressed(start: secondRunStart, end: secondRunStart + 1),
        );
      },
    );
  });

  // The first of the queue's two invariants: either the reading is installed
  // and playing, or nothing is installed and the engine is silent. A caller
  // that is told a reading failed is about to replace the player with an
  // error, and the reading before it must not still be talking behind that.
  group('ReadingQueue · a reading that fails leaves nothing talking', () {
    test('a reading with nothing to say silences the one before it', () async {
      await queue.speak(_mixed);

      final outcome = await queue.speak('   ');

      expect(outcome, const Err<int, AppFailure>(TtsFailure()));
      expect(tts.stopCount, 1);
      await completeUtterance();
      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('a missing Arabic voice silences the reading before it', () async {
      await queue.speak(_mixed);
      tts.voices = [_englishVoice];

      final outcome = await queue.speak('فاتورة كهرباء');

      expect(outcome, const Err<int, AppFailure>(NoArabicVoiceFailure()));
      expect(tts.stopCount, 1);
      await completeUtterance();
      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('the engine refusing the new reading silences the old one', () async {
      await queue.speak(_mixed);
      tts.speakFails = true;

      final outcome = await queue.speak('فاتورة كهرباء');

      expect(outcome, const Err<int, AppFailure>(TtsFailure()));
      expect(tts.stopCount, 1);
      tts.speakFails = false;
      await completeUtterance();
      expect(tts.spoken, [_mixedRuns.first, 'فاتورة كهرباء']);
    });

    test('a run refused mid-queue silences the engine as well', () async {
      await queue.speak(_mixed);
      tts.speakFails = true;
      await completeUtterance();

      expect(events.whereType<TtsFailed>(), const [TtsFailed()]);
      expect(tts.stopCount, 1);
    });

    test('a reading another one superseded silences nothing', () async {
      // Both in flight at once: the first stands down when it finds the
      // engine claimed, and must not stop the reading that claimed it.
      final first = queue.speak(_mixed);
      final second = queue.speak('فاتورة تانية');

      expect(await first, const Ok<int, AppFailure>(_mixed.length));
      expect(await second, const Ok<int, AppFailure>(12));
      expect(tts.stopCount, 0);
      expect(tts.spoken, const ['فاتورة تانية']);
    });
  });

  // The second invariant: nothing is spoken while the player is paused. The
  // gap between two runs is what made this worth its own code — a pause
  // landing there pauses an engine that is not speaking, so it has nothing to
  // report now and nothing to continue later.
  group('ReadingQueue · paused', () {
    test('a run that comes due while paused waits for resume', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsStarted());
      await settle();

      await queue.pause();
      await completeUtterance();

      expect(tts.spoken, [_mixedRuns.first]);

      expect(await queue.resume(), const Ok<void, AppFailure>(null));
      await settle();
      expect(tts.spoken, _mixedRuns.take(2));
      // The engine had nothing paused to continue, so resuming was the
      // hand-over itself and not a continue.
      expect(tts.resumeCount, 0);
    });

    test('resuming a run the engine still holds continues it', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsStarted());
      await settle();

      await queue.pause();
      await queue.resume();

      expect(tts.pauseCount, 1);
      expect(tts.resumeCount, 1);
      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('a pause the engine refuses does not hold the queue up', () async {
      tts.pauseFails = true;
      await queue.speak(_mixed);

      expect(await queue.pause(), const Err<void, AppFailure>(TtsFailure()));
      await completeUtterance();

      // Still reading, as the engine still is.
      expect(tts.spoken, _mixedRuns.take(2));
    });

    test('a resume the engine refuses gives the reading up', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsStarted());
      await settle();
      await queue.pause();

      tts.resumeFails = true;
      expect(await queue.resume(), const Err<void, AppFailure>(TtsFailure()));

      // Nothing is going to speak this reading now, so nothing of it may be
      // left installed: the Settings voice preview is outside this queue, and
      // its completion would otherwise advance a reading the user has already
      // been told failed.
      expect(tts.stopCount, 1);
      await completeUtterance();
      expect(tts.spoken, [_mixedRuns.first]);
    });

    test(
      'a refused resume silences nothing if a reading replaced it',
      () async {
        await queue.speak(_mixed);
        tts.emitEvent(const TtsStarted());
        await settle();
        await queue.pause();
        tts.resumeFails = true;

        // Both in flight at once: the user taps resume, and starts a fresh
        // reading from the options sheet before the engine has answered. The
        // refusal belongs to a reading that has been replaced — reporting it
        // would put a failure over the new one, and giving up on it would
        // silence the reading the user actually asked for.
        final resumed = queue.resume();
        final second = queue.speak('فاتورة تانية');

        expect(await resumed, const Ok<void, AppFailure>(null));
        expect(await second, const Ok<int, AppFailure>(12));
        expect(tts.stopCount, 0);
        expect(tts.spoken, [_mixedRuns.first, 'فاتورة تانية']);
      },
    );

    test('a parked run the engine refuses gives the reading up', () async {
      await queue.speak(_mixed);
      await queue.pause();
      await completeUtterance();

      tts.speakFails = true;
      expect(await queue.resume(), const Err<void, AppFailure>(TtsFailure()));

      expect(tts.stopCount, 1);
      tts.speakFails = false;
      await completeUtterance();
      expect(tts.spoken, [_mixedRuns.first, _mixedRuns.elementAt(1)]);
    });

    test(
      'a pause mid-hand-over parks the run instead of speaking it',
      () async {
        await queue.speak(_mixed);
        final gate = Completer<void>();
        tts.setVoiceGate = gate;

        // The completion starts the hand-over for the second run, which blocks
        // on the voice switch; the user pauses inside that window.
        tts.emitEvent(const TtsCompleted());
        await settle();
        await queue.pause();
        gate.complete();
        tts.setVoiceGate = null;
        await settle();

        expect(tts.spoken, [_mixedRuns.first]);

        await queue.resume();
        await settle();
        expect(tts.spoken, _mixedRuns.take(2));
      },
    );

    test('stopping while paused drops the run that was waiting', () async {
      await queue.speak(_mixed);
      await queue.pause();
      await completeUtterance();

      await queue.stop();
      await queue.resume();
      await settle();

      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('a new reading is never paused by the one before it', () async {
      await queue.speak(_mixed);
      await queue.pause();

      await queue.speak('فاتورة تانية');

      expect(tts.spoken, [_mixedRuns.first, 'فاتورة تانية']);
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

    test('stop mid-hand-over keeps the run from being spoken', () async {
      await queue.speak(_mixed);
      final gate = Completer<void>();
      tts.setVoiceGate = gate;

      // The completion starts the second run's hand-over, which blocks on the
      // voice switch; the user stops inside that window — the mirror of the
      // pause that lands there, and the other half of «including mid-run».
      tts.emitEvent(const TtsCompleted());
      await settle();
      await queue.stop();
      gate.complete();
      tts.setVoiceGate = null;
      await settle();

      expect(tts.spoken, [_mixedRuns.first]);
      // Nothing was parked either: a stop drops the reading, and resuming
      // after it must not find a run to speak.
      await queue.resume();
      await settle();
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
        // A permanent one: a transient error is spoken again once before
        // anything is reported (F30-T16), which the group below covers.
        const failed = TtsFailed(code: TtsErrorCode.service);

        await queue.speak(_mixed);
        tts.emitEvent(failed);
        await settle();
        await completeUtterance();

        expect(tts.spoken, [_mixedRuns.first]);
        expect(events.whereType<TtsFailed>(), const [failed]);
      },
    );

    test(
      'a continue counts as the run speaking, the same as a start',
      () async {
        // Android reports a continue rather than a start for the first
        // utterance after a pause — including the first run of a reading begun
        // while the engine was left paused. A queue that did not count it
        // would then mistake an outsider's cancel for the flush of its own
        // reading and keep queueing into an engine somebody else has.
        await queue.speak(_mixed);
        tts.emitEvent(const TtsContinued());
        await settle();

        tts.emitEvent(const TtsCancelled());
        await settle();
        await completeUtterance();

        expect(tts.spoken, [_mixedRuns.first]);
      },
    );

    test(
      'a completion arriving during a hand-over is not a run of ours',
      () async {
        // Nothing of the queue's is speaking between choosing an utterance and
        // the engine accepting it, so a completion in that window belongs to
        // something else — the reading being replaced, or an engine reporting
        // one utterance twice. Acting on it would skip a run.
        await queue.speak(_mixed);
        final gate = Completer<void>();
        tts.setVoiceGate = gate;

        tts.emitEvent(const TtsCompleted());
        await settle();
        tts.emitEvent(const TtsCompleted());
        await settle();
        gate.complete();
        tts.setVoiceGate = null;
        await settle();

        expect(tts.spoken, _mixedRuns.take(2));
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
      'reads a run it has no voice for in the letters it does have',
      () async {
        // No English voice: the English run is written in Arabic letters and
        // read by the Arabic voice (F30-T17), rather than handed to a voice
        // that would name its characters one at a time.
        tts.voices = [_arabicVoice];

        await queue.speak(_mixed);
        await completeUtterance();

        expect(tts.spoken, const ['فاتورة', ' إنفويس']);
        expect(tts.voicesSet, const [_arabicVoice, _arabicVoice]);
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

  // F30-T15. Android refuses an utterance over `getMaxSpeechInputLength()`
  // by parking the call — it never answers and emits no event — so a run
  // over the limit used to hang the reader with a bar that never went away
  // (F30 RC-3). A run too long for the engine is several queue items now,
  // and everything the queue does has to go on working across them.
  group('ReadingQueue · a run too long for the engine', () {
    /// A wholly Arabic reading of 30 code units, in words of 4 so a cut can
    /// land on a space wherever the limit falls.
    const long = 'اااا اااا اااا اااا اااا اااا';

    test('is spoken as several utterances, none over the limit', () async {
      tts.maxInputLength = 10;

      final outcome = await queue.speak(long);

      expect(outcome, const Ok<int, AppFailure>(long.length));
      expect(tts.spoken, const ['اااا اااا ']);

      await completeUtterance();
      await completeUtterance();
      expect(tts.spoken.join(), long);
      expect(tts.spoken.every((u) => u.length <= 10), isTrue);
    });

    test('is still one reading, finishing once at the end', () async {
      tts.maxInputLength = 10;

      await queue.speak(long);
      await completeUtterance();
      expect(events.whereType<TtsCompleted>(), isEmpty);

      await completeUtterance();
      await completeUtterance();
      expect(events.whereType<TtsCompleted>(), const [TtsCompleted()]);
    });

    test('keeps the run\'s own voice across its pieces', () async {
      tts.maxInputLength = 10;

      await queue.speak(long);
      await completeUtterance();
      await completeUtterance();

      // Cutting a run is about the engine's ceiling, not about language:
      // every piece of an Arabic run is still Arabic.
      expect(tts.voicesSet, const [_arabicVoice, _arabicVoice, _arabicVoice]);
    });

    test('progress goes on counting against the whole reading', () async {
      tts.maxInputLength = 10;

      await queue.speak(long);
      await completeUtterance();
      tts.emitEvent(const TtsProgressed(start: 0, end: 4));
      await settle();

      // The second piece starts 10 code units in, and the engine counts
      // from zero inside it — the bar must not jump back to the top of the
      // paper at a cut any more than it does at a language switch.
      expect(
        events.whereType<TtsProgressed>().last,
        const TtsProgressed(start: 10, end: 14),
      );
    });

    test('a pause between two pieces parks the next one', () async {
      tts.maxInputLength = 10;

      await queue.speak(long);
      await queue.pause();
      await completeUtterance();

      // The second invariant, at a cut rather than at a language boundary:
      // nothing is spoken while the player is paused.
      expect(tts.spoken, const ['اااا اااا ']);

      await queue.resume();
      await settle();
      expect(tts.spoken, hasLength(2));
    });

    test('cuts each run separately, not the reading as a whole', () async {
      // A limit short enough to cut the Arabic runs of the mixed reading but
      // not its English one: a piece never spans two languages, or the voice
      // switch the queue exists for would be lost.
      tts.maxInputLength = 8;

      await queue.speak(_mixed);
      for (var i = 0; i < 4; i++) {
        await completeUtterance();
      }

      expect(tts.spoken.join(), _mixed);
      expect(tts.spoken, hasLength(greaterThan(_mixedRuns.length)));
      expect(tts.voicesSet.first, _arabicVoice);
      expect(tts.voicesSet[1], _englishVoice);
    });

    test('leaves a reading inside the limit as one utterance', () async {
      tts.maxInputLength = 4000;

      await queue.speak(long);

      expect(tts.spoken, const [long]);
    });

    test('asks the engine for its limit once per reading', () async {
      tts.maxInputLength = 10;

      await queue.speak(long);
      await completeUtterance();
      await completeUtterance();

      // Same reason `getVoices` is asked once: it is a channel round trip on
      // the path F30 RC-6 is about keeping short.
      expect(tts.maxInputLengthCount, 1);
    });

    test('speaks the whole reading when no limit is declared', () async {
      // iOS, where the call is not implemented at all.
      tts.maxInputLength = null;

      await queue.speak(long);

      expect(tts.spoken, const [long]);
    });
  });

  // F30-T16, and the half of RC-2 the user feels. Android reports conditions
  // that pass on their own — a voice still downloading, a network voice that
  // could not fetch its audio — through the same handler as a dead engine,
  // and every one of them used to close the player and ask the user to tap
  // again. The owner's reading working on the third attempt is what that
  // looks like from the outside.
  group('ReadingQueue · a passing engine error is tried again', () {
    test('speaks the item that failed again, saying nothing', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      expect(tts.spoken, [_mixedRuns.first, _mixedRuns.first]);
      // Silent: no failure reaches the player, so no bar closes and no
      // message appears (locked decision 10 — the retry has no string).
      expect(events.whereType<TtsFailed>(), isEmpty);
    });

    test('carries on through the rest of the reading afterwards', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.notInstalledYet));
      await settle();
      await completeUtterance();

      expect(tts.spoken, [
        _mixedRuns.first,
        _mixedRuns.first,
        _mixedRuns.elementAt(1),
      ]);
    });

    test('an error the engine did not explain is tried again too', () async {
      // "We do not know" is the kind the owner retried by hand until it
      // worked, and the kind `TtsErrorCode.unknown` is deliberately
      // transient for.
      await queue.speak(_mixed);
      tts.emitEvent(const TtsFailed());
      await settle();

      expect(tts.spoken, [_mixedRuns.first, _mixedRuns.first]);
    });

    test('gives the reading up when the retry fails too', () async {
      const failed = TtsFailed(code: TtsErrorCode.network);

      await queue.speak(_mixed);
      tts.emitEvent(failed);
      await settle();
      tts.emitEvent(failed);
      await settle();

      // Twice would be a loop the user can neither see nor get out of.
      expect(tts.spoken, [_mixedRuns.first, _mixedRuns.first]);
      expect(events.whereType<TtsFailed>(), const [failed]);
      // And the queue is gone with it.
      await completeUtterance();
      expect(tts.spoken, hasLength(2));
    });

    test('a permanent error is not tried again at all', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.service));
      await settle();

      // Retrying what the engine called permanent is a second failure and a
      // longer wait before the user is told the truth.
      expect(tts.spoken, [_mixedRuns.first]);
      expect(events.whereType<TtsFailed>(), const [
        TtsFailed(code: TtsErrorCode.service),
      ]);
    });

    test('each queue item gets its own retry', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();
      await completeUtterance();
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      // A long paper is many items, and a network voice that drops one of
      // them may drop another later without either being a reading the user
      // should have to restart.
      expect(tts.spoken, [
        _mixedRuns.first,
        _mixedRuns.first,
        _mixedRuns.elementAt(1),
        _mixedRuns.elementAt(1),
      ]);
      expect(events.whereType<TtsFailed>(), isEmpty);
    });

    test('a retry that comes due while paused is parked, not spoken', () async {
      await queue.speak(_mixed);
      await queue.pause();
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      // The second invariant holds over the retry as well: nothing is
      // spoken while the player is paused.
      expect(tts.spoken, [_mixedRuns.first]);

      await queue.resume();
      await settle();
      expect(tts.spoken, [_mixedRuns.first, _mixedRuns.first]);
    });

    test('a stopped reading is not retried', () async {
      await queue.speak(_mixed);
      await queue.stop();
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      expect(tts.spoken, [_mixedRuns.first]);
    });

    test('an error with nothing installed is passed on untouched', () async {
      // The Settings voice preview is the one thing that speaks outside the
      // queue, and its failure is not a reading to retry.
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      expect(tts.spoken, isEmpty);
      expect(events.whereType<TtsFailed>(), const [
        TtsFailed(code: TtsErrorCode.network),
      ]);
    });

    test(
      'an error arriving during a hand-over is not retried over it',
      () async {
        await queue.speak(_mixed);
        final gate = Completer<void>();
        tts.setVoiceGate = gate;

        // The completion starts the second run's hand-over, which blocks on
        // the voice switch; the failure that lands in that window belongs to
        // the utterance being replaced. Retrying on it would speak the
        // incoming run twice.
        tts.emitEvent(const TtsCompleted());
        await settle();
        tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
        await settle();
        gate.complete();
        tts.setVoiceGate = null;
        await settle();

        expect(tts.spoken, _mixedRuns.take(2));
      },
    );

    test('a fresh reading gets its own retry', () async {
      await queue.speak(_mixed);
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      await queue.speak('فاتورة تانية');
      tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await settle();

      expect(tts.spoken, [
        _mixedRuns.first,
        _mixedRuns.first,
        'فاتورة تانية',
        'فاتورة تانية',
      ]);
    });
  });

  // F30-T17, the last of RC-4 and the fallback inside locked decision 2's
  // Option A. A device with Arabic voices and no English one would hand the
  // English run to a voice that names its characters one at a time; written
  // in Arabic letters, the same words come out as words.
  group('ReadingQueue · an English run with no English voice', () {
    setUp(() => tts.voices = [_arabicVoice]);

    test('is written in Arabic letters and read by the Arabic voice', () async {
      await queue.speak(_mixed);
      await completeUtterance();

      expect(tts.spoken, const ['فاتورة', ' إنفويس']);
      expect(tts.voicesSet, const [_arabicVoice, _arabicVoice]);
    });

    test('still answers with the reading\'s own length', () async {
      // What the user sees is the paper, not what the engine was handed —
      // «إنفويس» is six letters where `invoice` is seven, and a bar measured
      // against the shorter one would never reach its end.
      final outcome = await queue.speak(_mixed);

      expect(outcome, const Ok<int, AppFailure>(_mixed.length));
    });

    test('progress still spans the run it covers', () async {
      await queue.speak(_mixed);
      await completeUtterance();

      const transliterated = ' إنفويس';
      const runStart = 6;
      const runLength = 8;

      // The start of the transliterated utterance is the start of the run,
      // and its end is the end of the run — whatever happened to the
      // character count in between.
      tts.emitEvent(const TtsProgressed(start: 0, end: 0));
      await settle();
      expect(
        events.whereType<TtsProgressed>().last,
        const TtsProgressed(start: runStart, end: runStart),
      );

      tts.emitEvent(const TtsProgressed(start: 0, end: transliterated.length));
      await settle();
      expect(
        events.whereType<TtsProgressed>().last,
        const TtsProgressed(start: runStart, end: runStart + runLength),
      );
    });

    test('the run after it starts where it always did', () async {
      await queue.speak(_mixed);
      await completeUtterance();
      await completeUtterance();

      // The third run is Arabic and untouched, so its offsets are a plain
      // shift again — by the *paper's* lengths, not the spoken ones.
      tts.emitEvent(const TtsProgressed(start: 0, end: 4));
      await settle();

      const thirdRunStart = 14;
      expect(
        events.whereType<TtsProgressed>().last,
        const TtsProgressed(start: thirdRunStart, end: thirdRunStart + 4),
      );
    });

    test('is cut to the engine\'s limit after it is rewritten', () async {
      // The ceiling is on what the engine is handed, and that is the Arabic
      // text — the Latin it came from is never spoken (F30-T15).
      tts.maxInputLength = 4;

      await queue.speak('Pay before Friday');

      expect(tts.spoken.single.length, lessThanOrEqualTo(4));
    });

    test('leaves the run alone when an English voice exists', () async {
      tts.voices = [_arabicVoice, _englishVoice];

      await queue.speak(_mixed);
      await completeUtterance();

      expect(tts.spoken, _mixedRuns.take(2));
    });

    test('leaves it alone when there is no Arabic voice either', () async {
      // Nothing to rewrite it into: the device has a voice, but not one of
      // either language the app reads.
      tts.voices = const [TtsVoice(name: 'Amélie', locale: 'fr-FR')];

      await queue.speak('Pay before Friday');

      expect(tts.spoken, const ['Pay before Friday']);
      expect(tts.voicesSet, isEmpty);
    });

    test('leaves it alone when the device reports no voices at all', () async {
      // Android answers with an empty list while its engine is binding, and
      // that is not evidence that an English voice is missing.
      tts.voices = const [];

      await queue.speak(_mixed);
      await completeUtterance();

      expect(tts.spoken, _mixedRuns.take(2));
    });
  });
}
