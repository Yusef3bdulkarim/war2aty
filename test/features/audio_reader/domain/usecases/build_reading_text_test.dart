import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';

import '../../../../features/analysis/analysis_fixtures.dart';

const _buildResult = BuildAnalysisResult();
const _ocrText = '  فاتورة كهرباء عن شهر مارس  ';

void main() {
  const useCase = BuildReadingText();
  const ar = ArStrings();

  group('BuildReadingText', () {
    test('summaryOnly reads the one-line summary, trimmed', () {
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: _ocrText,
      );

      final text = useCase(
        result: result,
        mode: ReadingMode.summaryOnly,
        strings: ar,
      );

      expect(text, invoiceAnalysis().summary.short);
    });

    test('fullExplanation reads the detailed explanation untouched', () {
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: _ocrText,
      );

      final text = useCase(
        result: result,
        mode: ReadingMode.fullExplanation,
        strings: ar,
      );

      expect(text, invoiceAnalysis().summary.detailed);
    });

    test('extractedText reads the raw OCR text, trimmed', () {
      final result = _buildResult(
        analysis: invoiceAnalysis(),
        extractedText: _ocrText,
      );

      final text = useCase(
        result: result,
        mode: ReadingMode.extractedText,
        strings: ar,
      );

      expect(text, _ocrText.trim());
    });

    test(
      'summaryAndKeyInformation follows the summary with each labelled fact',
      () {
        final result = _buildResult(
          analysis: invoiceAnalysis(),
          extractedText: _ocrText,
        );

        final text = useCase(
          result: result,
          mode: ReadingMode.summaryAndKeyInformation,
          strings: ar,
        );

        expect(
          text,
          '${invoiceAnalysis().summary.short}. '
          '${ar.resultKeyInformationTitle}. '
          'رقم الحساب: 1234',
        );
      },
    );

    test('summaryAndKeyInformation never reads an uncertain value as fact', () {
      final analysis = DocumentAnalysis(
        sessionId: 'session-uncertain',
        status: invoiceAnalysis().status,
        kind: invoiceAnalysis().kind,
        title: invoiceAnalysis().title,
        kindConfidence: invoiceAnalysis().kindConfidence,
        summary: invoiceAnalysis().summary,
        keyInformation: const [
          KeyInformation(
            label: 'رقم العداد',
            value: '998877',
            confidence: ConfidenceBand.low,
            source: InfoSource.inferred,
          ),
        ],
      );
      final result = _buildResult(analysis: analysis, extractedText: '');

      final text = useCase(
        result: result,
        mode: ReadingMode.summaryAndKeyInformation,
        strings: ar,
      );

      expect(text, contains(ar.confidenceUncertain));
      expect(text, contains(ar.resultActionInferred));
      expect(
        text,
        endsWith(
          'رقم العداد: 998877. ${ar.confidenceUncertain}. ${ar.resultActionInferred}',
        ),
      );
    });

    test('summaryAndKeyInformation falls back to the summary alone when there '
        'is no key information', () {
      final analysis = DocumentAnalysis(
        sessionId: 'session-no-key-info',
        status: invoiceAnalysis().status,
        kind: invoiceAnalysis().kind,
        title: invoiceAnalysis().title,
        kindConfidence: invoiceAnalysis().kindConfidence,
        summary: invoiceAnalysis().summary,
      );
      final result = _buildResult(analysis: analysis, extractedText: '');

      final text = useCase(
        result: result,
        mode: ReadingMode.summaryAndKeyInformation,
        strings: ar,
      );

      expect(text, invoiceAnalysis().summary.short);
    });

    test('a whitespace-only summary reads as nothing rather than crashing', () {
      final result = _buildResult(
        analysis: invoiceAnalysis(
          summary: const AnalysisSummary(short: '   ', detailed: '\n '),
        ),
        extractedText: _ocrText,
      );

      expect(
        useCase(result: result, mode: ReadingMode.summaryOnly, strings: ar),
        isEmpty,
      );
      expect(
        useCase(result: result, mode: ReadingMode.fullExplanation, strings: ar),
        isEmpty,
      );
    });
  });
}
