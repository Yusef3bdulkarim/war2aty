import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/audio_reader_state.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/analysis_result.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_event.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_raw_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';

import '../../features/analysis/analysis_fixtures.dart';
import '../../support/fakes.dart';

const _buildResult = BuildAnalysisResult();
const _ar = ArStrings();

final AnalysisResult _result = _buildResult(
  analysis: invoiceAnalysis(),
  extractedText: '',
);

/// A cubit and the fake engine behind it, wired the same way DI does.
///
/// [defaultSpeed]/[defaultVoice] model Settings' own persisted picks
/// (F11-T07) — `null` defaults, same as a user who has never touched either.
({AudioReaderCubit cubit, FakeTextToSpeechService tts}) _cubitFor({
  bool speakFails = false,
  bool stopFails = false,
  bool pauseFails = false,
  bool resumeFails = false,
  bool setSpeechRateFails = false,
  List<TtsVoice> voices = const [],
  ReadingSpeed? defaultSpeed,
  TtsVoice? defaultVoice,
}) {
  final tts = FakeTextToSpeechService(
    speakFails: speakFails,
    stopFails: stopFails,
    pauseFails: pauseFails,
    resumeFails: resumeFails,
    setSpeechRateFails: setSpeechRateFails,
    voices: voices,
  );
  final cubit = AudioReaderCubit(
    StartReading(const BuildReadingText(), const SelectVoiceForReading(), tts),
    StartRawReading(const SelectVoiceForReading(), tts),
    StopReading(tts),
    PauseReading(tts),
    ResumeReading(tts),
    SetReadingSpeed(tts),
    WatchReadingEvents(tts),
    GetDefaultReadingSpeed(FakeDefaultReadingSpeedStore(defaultSpeed)),
    GetDefaultReadingVoice(FakeDefaultReadingVoiceStore(defaultVoice)),
  );
  return (cubit: cubit, tts: tts);
}

void main() {
  group('AudioReaderCubit', () {
    test('starts idle', () {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      expect(built.cubit.state, const AudioReaderIdle());
    });

    test('start speaks the mode and reports it as reading', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.summaryOnly),
      );
      expect(built.tts.spoken, [invoiceAnalysis().summary.short]);
    });

    test('speaking a second mode replaces what was reading', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.fullExplanation,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.fullExplanation),
      );
      expect(built.tts.spoken, [
        invoiceAnalysis().summary.short,
        invoiceAnalysis().summary.detailed,
      ]);
    });

    test('a failed start reports the failure instead', () async {
      final built = _cubitFor(speakFails: true);
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      expect(built.cubit.state, const AudioReaderFailed(TtsFailure()));
    });

    test('pause holds the engine and marks the mode paused', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      await built.cubit.pause();

      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.summaryOnly, isPaused: true),
      );
      expect(built.tts.pauseCount, 1);
    });

    test('resume continues the engine and clears paused', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      await built.cubit.pause();

      await built.cubit.resume();

      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.summaryOnly),
      );
      expect(built.tts.resumeCount, 1);
    });

    test('a failed pause reports the failure instead', () async {
      final built = _cubitFor(pauseFails: true);
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      await built.cubit.pause();

      expect(built.cubit.state, const AudioReaderFailed(TtsFailure()));
    });

    test('a failed resume reports the failure instead', () async {
      final built = _cubitFor(resumeFails: true);
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      await built.cubit.pause();

      await built.cubit.resume();

      expect(built.cubit.state, const AudioReaderFailed(TtsFailure()));
    });

    test('pausing twice only touches the engine once', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      await built.cubit.pause();
      await built.cubit.pause();

      expect(built.tts.pauseCount, 1);
    });

    test('resuming without pausing first does not touch the engine', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      await built.cubit.resume();

      expect(built.tts.resumeCount, 0);
      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.summaryOnly),
      );
    });

    test('pausing while idle does not touch the engine', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.pause();

      expect(built.tts.pauseCount, 0);
      expect(built.cubit.state, const AudioReaderIdle());
    });

    test('stop silences the engine and goes back to idle', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      await built.cubit.stop();

      expect(built.cubit.state, const AudioReaderIdle());
      expect(built.tts.stopCount, 1);
    });

    test('a failed stop still lands on idle, after reporting it', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      built.tts.stopFails = true;

      final expectation = expectLater(
        built.cubit.stream,
        emitsInOrder([
          const AudioReaderFailed(TtsFailure()),
          const AudioReaderIdle(),
        ]),
      );
      await built.cubit.stop();
      await expectation;

      expect(built.cubit.state, const AudioReaderIdle());
    });

    test('closing while reading stops the engine', () async {
      final built = _cubitFor();
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      await built.cubit.close();
      // `close` fires the stop without waiting on it — give the microtask
      // queue a turn to run it before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(built.tts.stopCount, 1);
    });

    test('closing while idle does not touch the engine', () async {
      final built = _cubitFor();
      addTearDown(built.tts.dispose);

      await built.cubit.close();
      await Future<void>.delayed(Duration.zero);

      expect(built.tts.stopCount, 0);
    });
  });

  group('reading speed (F10-T06)', () {
    test('start applies the chosen speed before speaking', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.fastest,
        strings: _ar,
      );

      expect(built.tts.speechRates, [ReadingSpeed.fastest.rate]);
      expect(
        built.cubit.state,
        const AudioReaderReading(
          ReadingMode.summaryOnly,
          speed: ReadingSpeed.fastest,
        ),
      );
    });

    test('pause and resume keep the speed the reading started at', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.faster,
        strings: _ar,
      );

      await built.cubit.pause();
      expect(
        built.cubit.state,
        const AudioReaderReading(
          ReadingMode.summaryOnly,
          isPaused: true,
          speed: ReadingSpeed.faster,
        ),
      );

      await built.cubit.resume();
      expect(
        built.cubit.state,
        const AudioReaderReading(
          ReadingMode.summaryOnly,
          speed: ReadingSpeed.faster,
        ),
      );
    });

    test(
      'restarting at a new speed re-applies the rate and restarts',
      () async {
        final built = _cubitFor();
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);
        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.normal,
          strings: _ar,
        );

        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.slower,
          strings: _ar,
        );

        expect(built.tts.speechRates, [
          ReadingSpeed.normal.rate,
          ReadingSpeed.slower.rate,
        ]);
        expect(
          built.cubit.state,
          const AudioReaderReading(
            ReadingMode.summaryOnly,
            speed: ReadingSpeed.slower,
          ),
        );
      },
    );

    test(
      'a failed rate change is reported but the read starts anyway',
      () async {
        final built = _cubitFor(setSpeechRateFails: true);
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);

        final expectation = expectLater(
          built.cubit.stream,
          emitsInOrder([
            const AudioReaderFailed(TtsFailure()),
            const AudioReaderReading(
              ReadingMode.summaryOnly,
              speed: ReadingSpeed.faster,
            ),
          ]),
        );
        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.faster,
          strings: _ar,
        );
        await expectation;

        expect(built.tts.spoken, [invoiceAnalysis().summary.short]);
      },
    );
  });

  group('default audio prefs (F11-T07)', () {
    test('loadDefaultSpeed answers the persisted default', () async {
      final built = _cubitFor(defaultSpeed: ReadingSpeed.faster);
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      expect(await built.cubit.loadDefaultSpeed(), ReadingSpeed.faster);
    });

    test('loadDefaultSpeed falls back to normal untouched', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      expect(await built.cubit.loadDefaultSpeed(), ReadingSpeed.normal);
    });

    test(
      'start applies the persisted default voice ahead of speaking',
      () async {
        const voice = TtsVoice(name: 'Voice A', locale: 'ar-EG');
        final built = _cubitFor(defaultVoice: voice);
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);

        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.normal,
          strings: _ar,
        );

        expect(built.tts.voicesSet, [voice]);
      },
    );

    test(
      'start falls back to the automatic script match with no default voice',
      () async {
        const arabicVoice = TtsVoice(name: 'Voice A', locale: 'ar-EG');
        final built = _cubitFor(voices: [arabicVoice]);
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);

        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.normal,
          strings: _ar,
        );

        expect(built.tts.voicesSet, [arabicVoice]);
      },
    );
  });

  group('progress tracking (F10-T08)', () {
    final length = invoiceAnalysis().summary.short.length;

    test('a fresh reading starts at zero progress', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.summaryOnly, progress: 0),
      );
    });

    test('a progress event turns into a fraction of the spoken text', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      built.tts.emitEvent(TtsProgressed(start: 0, end: length ~/ 2));
      await Future<void>.delayed(Duration.zero);

      expect(
        built.cubit.state,
        AudioReaderReading(
          ReadingMode.summaryOnly,
          progress: (length ~/ 2) / length,
        ),
      );
    });

    test(
      'progress never reports past 1, even if the engine overshoots',
      () async {
        final built = _cubitFor();
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);
        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.normal,
          strings: _ar,
        );

        built.tts.emitEvent(TtsProgressed(start: 0, end: length + 50));
        await Future<void>.delayed(Duration.zero);

        expect(
          built.cubit.state,
          const AudioReaderReading(ReadingMode.summaryOnly, progress: 1),
        );
      },
    );

    test('a progress event is ignored while nothing is reading', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      built.tts.emitEvent(const TtsProgressed(start: 0, end: 5));
      await Future<void>.delayed(Duration.zero);

      expect(built.cubit.state, const AudioReaderIdle());
    });

    test('a reading finishing on its own hides the mini-player', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      built.tts.emitEvent(const TtsCompleted());
      await Future<void>.delayed(Duration.zero);

      expect(built.cubit.state, const AudioReaderIdle());
    });

    test('pausing keeps whatever progress was last reported', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      built.tts.emitEvent(TtsProgressed(start: 0, end: length ~/ 4));
      await Future<void>.delayed(Duration.zero);
      final progressBeforePause =
          (built.cubit.state as AudioReaderReading).progress;

      await built.cubit.pause();

      expect(
        built.cubit.state,
        AudioReaderReading(
          ReadingMode.summaryOnly,
          isPaused: true,
          progress: progressBeforePause,
        ),
      );
    });

    test('a fresh start resets progress back to zero', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      built.tts.emitEvent(TtsProgressed(start: 0, end: length - 1));
      await Future<void>.delayed(Duration.zero);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.fullExplanation,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      expect(
        built.cubit.state,
        const AudioReaderReading(ReadingMode.fullExplanation, progress: 0),
      );
    });

    test('progress never falls back after a resume that restarts from the '
        'unread remainder (Android\'s own flutter_tts behaviour)', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      // Most of the way through, then paused.
      built.tts.emitEvent(TtsProgressed(start: 0, end: length - 2));
      await Future<void>.delayed(Duration.zero);
      await built.cubit.pause();
      await built.cubit.resume();

      // The resumed utterance covers only the unread remainder, so its own
      // progress event counts from zero again.
      built.tts.emitEvent(const TtsProgressed(start: 0, end: 1));
      await Future<void>.delayed(Duration.zero);

      expect(
        built.cubit.state,
        AudioReaderReading(
          ReadingMode.summaryOnly,
          progress: (length - 2) / length,
        ),
      );
    });

    test(
      'an engine failure mid-reading reports it rather than freezing the bar',
      () async {
        final built = _cubitFor();
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);
        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.normal,
          strings: _ar,
        );

        built.tts.emitEvent(const TtsFailed());
        await Future<void>.delayed(Duration.zero);

        expect(built.cubit.state, const AudioReaderFailed(TtsFailure()));
      },
    );

    test('an engine failure while idle is ignored', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      built.tts.emitEvent(const TtsFailed());
      await Future<void>.delayed(Duration.zero);

      expect(built.cubit.state, const AudioReaderIdle());
    });

    test(
      'stopping while reading does not leave a stale subscriber behind',
      () async {
        final built = _cubitFor();
        addTearDown(built.tts.dispose);
        await built.cubit.start(
          result: _result,
          mode: ReadingMode.summaryOnly,
          speed: ReadingSpeed.normal,
          strings: _ar,
        );

        await built.cubit.close();
        await Future<void>.delayed(Duration.zero);
        // Nothing should throw from an event delivered after close.
        built.tts.emitEvent(const TtsProgressed(start: 0, end: 1));
        await Future<void>.delayed(Duration.zero);
      },
    );
  });
}
