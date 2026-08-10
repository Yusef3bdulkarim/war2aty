import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/audio_reader_state.dart';
import 'package:war2aty/core/documents/analysis_result.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/audio_reader/domain/entities/reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';

import '../../features/analysis/analysis_fixtures.dart';
import '../../support/fakes.dart';

const _buildResult = BuildAnalysisResult();
const _ar = ArStrings();

final AnalysisResult _result = _buildResult(
  analysis: invoiceAnalysis(),
  extractedText: '',
);

/// A cubit and the fake engine behind it, wired the same way DI does.
({AudioReaderCubit cubit, FakeTextToSpeechService tts}) _cubitFor({
  bool speakFails = false,
  bool stopFails = false,
  bool pauseFails = false,
  bool resumeFails = false,
  bool setSpeechRateFails = false,
}) {
  final tts = FakeTextToSpeechService(
    speakFails: speakFails,
    stopFails: stopFails,
    pauseFails: pauseFails,
    resumeFails: resumeFails,
    setSpeechRateFails: setSpeechRateFails,
  );
  final cubit = AudioReaderCubit(
    StartReading(const BuildReadingText(), tts),
    StopReading(tts),
    PauseReading(tts),
    ResumeReading(tts),
    SetReadingSpeed(tts),
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
}
