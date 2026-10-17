import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/result/result.dart';
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

      expect(
        outcome,
        Ok<int, AppFailure>(invoiceAnalysis().summary.short.length),
      );
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

      expect(outcome, const Err<int, AppFailure>(TtsFailure()));
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

    // F30-T07 changed what this case does, deliberately. It used to leave
    // the voice alone and read the Arabic summary with whatever the engine
    // had — which on a phone with only an English voice means spelling out
    // the Latin characters and making no sound for the Arabic (F30 RC-1).
    test('an Arabic paper with no Arabic voice is refused, not read', () async {
      tts.voices = [englishVoice];
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      final outcome = await useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: _ar,
      );

      expect(outcome.failureOrNull, isA<NoArabicVoiceFailure>());
      // Nothing was spoken, and the English voice was never set.
      expect(tts.spoken, isEmpty);
      expect(tts.voicesSet, isEmpty);
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

      expect(
        outcome,
        Ok<int, AppFailure>(invoiceAnalysis().summary.short.length),
      );
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

      expect(
        outcome,
        Ok<int, AppFailure>(invoiceAnalysis().summary.short.length),
      );
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

      expect(
        outcome,
        Ok<int, AppFailure>(invoiceAnalysis().summary.short.length),
      );
      expect(tts.spoken, [invoiceAnalysis().summary.short]);
    });
  });

  // F30-T04. There is no stored Settings choice to override the automatic
  // match any more: the «صوت القراءة» picker was removed, which left nothing
  // able to write one, so every reading paid two database reads to learn it
  // was null. Voice choice is automatic, full stop.
  group('automatic voice choice (F30-T04)', () {
    const arabicVoice = TtsVoice(name: 'Maged', locale: 'ar-EG');
    const englishVoice = TtsVoice(name: 'Samantha', locale: 'en-US');

    test(
      'an Arabic summary gets the Arabic voice, not whichever is first',
      () async {
        // English listed first, so passing this means the script match ran
        // rather than the list order deciding.
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

        expect(tts.voicesSet, [arabicVoice]);
      },
    );

    test('the device is asked for its voices once per reading', () async {
      tts.voices = [arabicVoice, englishVoice];
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      await useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: _ar,
      );

      // The real service answers this from a cache (F30-T04), so the slow
      // platform call behind it no longer runs on every reading.
      expect(tts.getVoicesCount, 1);
    });
  });

  group('reported length (F10-T08)', () {
    test('reports the spoken text\'s own length, not a fixed number', () async {
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: '',
      );

      final outcome = await useCase(
        result: result,
        mode: ReadingMode.fullExplanation,
        strings: _ar,
      );

      expect(
        outcome,
        Ok<int, AppFailure>(invoiceAnalysis().summary.detailed.length),
      );
    });
  });
}
