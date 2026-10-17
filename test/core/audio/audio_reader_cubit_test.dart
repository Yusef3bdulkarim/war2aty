import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/audio_reader_state.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/tts_error_code.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/open_system_tts_settings.dart';
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
import 'package:war2aty/features/audio_reader/domain/usecases/warm_up_reader.dart';
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
/// [defaultSpeed] models Settings' own persisted pick (F11-T07) — `null` for
/// a user who has never touched it. There is no voice counterpart any more:
/// F30-T04 took the stored choice out of the reading path, since the picker
/// that wrote it was removed and the two database reads it cost happened on
/// every single reading.
({
  AudioReaderCubit cubit,
  FakeTextToSpeechService tts,
  FakeSystemTtsSettings ttsSettings,
})
_cubitFor({
  bool speakFails = false,
  bool stopFails = false,
  bool pauseFails = false,
  bool resumeFails = false,
  bool setSpeechRateFails = false,
  List<TtsVoice> voices = const [],
  ReadingSpeed? defaultSpeed,
  bool settingsAvailable = true,
  bool settingsOpen = true,
}) {
  final tts = FakeTextToSpeechService(
    speakFails: speakFails,
    stopFails: stopFails,
    pauseFails: pauseFails,
    resumeFails: resumeFails,
    setSpeechRateFails: setSpeechRateFails,
    voices: voices,
  );
  final ttsSettings = FakeSystemTtsSettings(
    available: settingsAvailable,
    opensSuccessfully: settingsOpen,
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
    WarmUpReader(tts),
    OpenSystemTtsSettings(ttsSettings, tts),
  );
  return (cubit: cubit, tts: tts, ttsSettings: ttsSettings);
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

    // F30-T07. The one voice problem the user can fix, and the one worth
    // stopping a reading over. Silently reading on with an English voice is
    // what made a Samsung phone spell out the Latin characters of an Arabic
    // paper and do nothing at all for «الخلاصة» (F30 RC-1).
    test('a device with no Arabic voice is told, not read to anyway', () async {
      final built = _cubitFor(
        voices: const [TtsVoice(name: 'Samantha', locale: 'en-US')],
      );
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
        isA<AudioReaderFailed>().having(
          (s) => s.failure,
          'failure',
          isA<NoArabicVoiceFailure>(),
        ),
      );
      // And nothing was read with the wrong voice.
      expect(built.tts.spoken, isEmpty);
      expect(built.tts.voicesSet, isEmpty);
    });

    test('an engine still binding is not accused of missing a voice', () async {
      // Android reports no voices at all until it finishes binding. Claiming
      // a missing Arabic voice on that basis would be wrong, and would send
      // the user off to install one they already have.
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      expect(built.cubit.state, isA<AudioReaderReading>());
      expect(built.tts.spoken, hasLength(1));
    });

    test('opening the settings forgets the cached voice list', () async {
      // The point of sending the user there is that they install a voice;
      // the cached list would still say they have none (F30-T04).
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      expect(await built.cubit.openSystemTtsSettings(), isTrue);

      expect(built.ttsSettings.openCount, 1);
      expect(built.tts.forgetVoicesCount, 1);
    });

    test(
      'a phone with no settings screen says so before offering it',
      () async {
        final built = _cubitFor(settingsAvailable: false);
        addTearDown(built.cubit.close);
        addTearDown(built.tts.dispose);

        expect(await built.cubit.canOpenSystemTtsSettings(), isFalse);
        expect(built.ttsSettings.availableCount, 1);
      },
    );

    test('an intent that fails once fired is reported as false', () async {
      final built = _cubitFor(settingsOpen: false);
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      expect(await built.cubit.openSystemTtsSettings(), isFalse);
    });

    test('the engine is warmed up as soon as the cubit exists', () async {
      // F30-T06. The screen that owns the mini-player builds this cubit
      // seconds before anyone reaches for «الاستماع», so the slow first
      // call belongs here rather than on the tap.
      final built = _cubitFor(
        voices: const [TtsVoice(name: 'ar-EG-local', locale: 'ar-EG')],
      );
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);

      // The warm-up is deliberately not awaited by the constructor, so give
      // the microtask it was fired on a chance to run.
      await Future<void>.delayed(Duration.zero);

      expect(built.tts.getVoicesCount, 1);
      // And it stays silent — a warm-up that spoke would have the result
      // screen talking the moment it opened.
      expect(built.tts.spoken, isEmpty);
      expect(built.cubit.state, isA<AudioReaderIdle>());
    });

    test(
      'start asks the engine for the voice, and nothing else for it',
      () async {
        // F30-T04. Starting a reading used to open the settings table twice
        // for a voice preference nothing could write, before it even reached
        // the engine. That dependency is gone from the constructor
        // altogether, so the only proof left to assert is that the voice
        // still arrives — the engine is now the single source of it.
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

    test('start picks the voice matching the text\'s own script', () async {
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
    });
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

        expect(
          built.cubit.state,
          const AudioReaderFailed(TtsFailure(TtsErrorCode.unknown)),
        );
      },
    );

    // F30-T08. One generic «حصلت مشكلة. جرّب تاني.» for every engine error is
    // what made the owner tap three times before a reading worked (RC-2).
    test('a transient engine error stays the retryable failure', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      built.tts.emitEvent(const TtsFailed(code: TtsErrorCode.network));
      await Future<void>.delayed(Duration.zero);

      expect(
        built.cubit.state,
        const AudioReaderFailed(TtsFailure(TtsErrorCode.network)),
      );
    });

    test('a permanent engine error is not offered as a retry', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );

      built.tts.emitEvent(const TtsFailed(code: TtsErrorCode.service));
      await Future<void>.delayed(Duration.zero);

      expect(
        built.cubit.state,
        const AudioReaderFailed(
          TtsEngineUnavailableFailure(TtsErrorCode.service),
        ),
      );
    });

    test('a failed reading still clears the bar\'s progress', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
        speed: ReadingSpeed.normal,
        strings: _ar,
      );
      built.tts.emitEvent(const TtsProgressed(start: 0, end: 5));
      await Future<void>.delayed(Duration.zero);

      built.tts.emitEvent(const TtsFailed(code: TtsErrorCode.service));
      await Future<void>.delayed(Duration.zero);
      // A second reading starts from zero, not from where the failed one
      // stopped.
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
    });

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
