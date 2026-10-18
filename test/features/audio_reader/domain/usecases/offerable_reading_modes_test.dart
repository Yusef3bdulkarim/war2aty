import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/offerable_reading_modes.dart';

import '../../../../features/analysis/analysis_fixtures.dart';

const _buildResult = BuildAnalysisResult();
const _ocrText = 'فاتورة كهرباء عن شهر مارس';

/// F30-T19. The sheet offered all four modes whatever the paper had in it,
/// while the screen above it only draws a section that has something in it.
/// So a paper whose summary came back blank still offered «التلخيص فقط», and
/// picking it sent the empty string to the engine (F30 "Secondary").
void main() {
  const useCase = OfferableReadingModes(BuildReadingText());
  const ar = ArStrings();

  List<ReadingMode> modesFor(DocumentAnalysis analysis, {String? ocrText}) =>
      useCase(
        result: _buildResult(
          analysis: analysis,
          extractedText: ocrText ?? _ocrText,
        ),
        strings: ar,
      );

  group('OfferableReadingModes', () {
    test('a full paper offers all four, in the sheet\'s own order', () {
      expect(modesFor(invoiceAnalysis()), OfferableReadingModes.candidates);
      expect(OfferableReadingModes.candidates, const [
        ReadingMode.summaryOnly,
        ReadingMode.summaryAndKeyInformation,
        ReadingMode.fullExplanation,
        ReadingMode.readAll,
      ]);
    });

    test('never offers the mode the sheet cannot reach', () {
      // `extractedText` has no analysis to summarise — it is read straight
      // away from the OCR-only fallback screens, never picked here.
      expect(
        modesFor(invoiceAnalysis()),
        isNot(contains(ReadingMode.extractedText)),
      );
    });

    test('a blank summary takes «التلخيص فقط» off the sheet', () {
      final modes = modesFor(
        invoiceAnalysis(
          summary: const AnalysisSummary(
            short: '   ',
            detailed: 'الشرح الكامل موجود.',
          ),
        ),
      );

      expect(modes, isNot(contains(ReadingMode.summaryOnly)));
      // The one beside it survives: it has the key information to read even
      // with no summary of its own.
      expect(modes, contains(ReadingMode.summaryAndKeyInformation));
      expect(modes, contains(ReadingMode.fullExplanation));
    });

    test('a blank explanation takes its own mode off too', () {
      final modes = modesFor(
        invoiceAnalysis(
          summary: const AnalysisSummary(short: 'فاتورة كهرباء.', detailed: ''),
        ),
      );

      expect(modes, isNot(contains(ReadingMode.fullExplanation)));
      expect(modes, contains(ReadingMode.summaryOnly));
    });

    test('a paper with nothing readable at all offers nothing', () {
      // Which also means the screen behind the sheet is blank: every section
      // it draws is read by `readAll`.
      const nothing = DocumentAnalysis(
        sessionId: 'session-1',
        status: AnalysisStatus.success,
        kind: DocumentKind.other,
        title: '',
        kindConfidence: ConfidenceBand.low,
        summary: AnalysisSummary(short: '', detailed: ''),
      );

      expect(modesFor(nothing, ocrText: '  '), isEmpty);
    });

    test('the extracted text alone is enough for «اقرأ كل حاجة»', () {
      const nothing = DocumentAnalysis(
        sessionId: 'session-1',
        status: AnalysisStatus.success,
        kind: DocumentKind.other,
        title: '',
        kindConfidence: ConfidenceBand.low,
        summary: AnalysisSummary(short: '', detailed: ''),
      );

      expect(modesFor(nothing), const [ReadingMode.readAll]);
    });
  });
}
