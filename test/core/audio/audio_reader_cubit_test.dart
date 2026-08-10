import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/audio_reader_state.dart';
import 'package:war2aty/core/documents/analysis_result.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
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
}) {
  final tts = FakeTextToSpeechService(
    speakFails: speakFails,
    stopFails: stopFails,
  );
  final cubit = AudioReaderCubit(
    StartReading(const BuildReadingText(), tts),
    StopReading(tts),
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
        strings: _ar,
      );
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.fullExplanation,
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
        strings: _ar,
      );

      expect(built.cubit.state, const AudioReaderFailed(TtsFailure()));
    });

    test('stop silences the engine and goes back to idle', () async {
      final built = _cubitFor();
      addTearDown(built.cubit.close);
      addTearDown(built.tts.dispose);
      await built.cubit.start(
        result: _result,
        mode: ReadingMode.summaryOnly,
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
}
