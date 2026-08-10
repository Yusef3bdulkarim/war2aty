import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_voice.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';

import '../../../../support/fakes.dart';
import '../../../analysis/analysis_fixtures.dart';

const _buildResult = BuildAnalysisResult();
const _buildReadingText = BuildReadingText();
const _selectVoice = SelectVoiceForReading();
const _ar = ArStrings();

void main() {
  late FakeTextToSpeechService tts;
  late StartReading useCase;

  setUp(() {
    tts = FakeTextToSpeechService();
    useCase = StartReading(_buildReadingText, _selectVoice, tts);
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

  group('default voice (F10-T07)', () {
    const arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
    const englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');

    test('switches to a voice matching the text before speaking', () async {
      tts.voices = [englishVoice, arabicVoice];
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      await useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: _ar,
      );

      // The fixture's summary is Arabic — the Arabic voice should win, not
      // just whichever voice happened to come first in the device's list.
      expect(tts.voicesSet, [arabicVoice]);
      expect(tts.spoken, [invoiceAnalysis().summary.short]);
    });

    test('leaves the voice untouched when the device has no match', () async {
      tts.voices = [englishVoice];
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      await useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: _ar,
      );

      expect(tts.voicesSet, isEmpty);
      expect(tts.spoken, [invoiceAnalysis().summary.short]);
    });

    test('reads anyway when the device reports no voices at all', () async {
      tts.voices = const [];
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
      expect(tts.voicesSet, isEmpty);
    });

    test('reads anyway when getVoices fails', () async {
      tts.getVoicesFails = true;
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

    test('reads anyway when setVoice fails', () async {
      tts.voices = [arabicVoice];
      tts.setVoiceFails = true;
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
  });
}
