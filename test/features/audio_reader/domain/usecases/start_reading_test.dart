import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';

import '../../../../support/fakes.dart';
import '../../../analysis/analysis_fixtures.dart';

const _buildResult = BuildAnalysisResult();
const _buildReadingText = BuildReadingText();
const _ar = ArStrings();

void main() {
  late FakeTextToSpeechService tts;
  late StartReading useCase;

  setUp(() {
    tts = FakeTextToSpeechService();
    useCase = StartReading(_buildReadingText, tts);
  });

  tearDown(() => tts.dispose());

  group('StartReading', () {
    test('speaks the text BuildReadingText builds for the mode', () async {
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      final outcome = await useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: _ar,
      );

      expect(outcome, const Ok<void, AppFailure>(null));
      expect(tts.spoken, [invoiceAnalysis().summary.short]);
    });

    test(
      "builds a different mode's text for it, not always the summary",
      () async {
        final result = _buildResult(
          analysis: invoiceAnalysis(),
          extractedText: '',
        );

        await useCase(
          result: result,
          mode: ReadingMode.fullExplanation,
          strings: _ar,
        );

        expect(tts.spoken, [invoiceAnalysis().summary.detailed]);
      },
    );

    test('reports the engine failure rather than swallowing it', () async {
      tts.speakFails = true;
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      final outcome = await useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: _ar,
      );

      expect(outcome, const Err<void, AppFailure>(TtsFailure()));
    });
  });
}
