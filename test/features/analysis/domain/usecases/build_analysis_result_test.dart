import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_section.dart';
import 'package:war2aty/features/analysis/domain/usecases/build_analysis_result.dart';

import '../../analysis_fixtures.dart';

const _ocrText = 'فاتورة كهرباء';

void main() {
  const useCase = BuildAnalysisResult();

  group('BuildAnalysisResult', () {
    test('orders every section the way master plan §4 fixes them', () {
      final result = useCase(
        analysis: invoiceAnalysis(),
        extractedText: _ocrText,
      );

      expect(result.sections, [
        AnalysisSection.header,
        AnalysisSection.summary,
        AnalysisSection.actionRequired,
        AnalysisSection.warnings,
        AnalysisSection.keyInformation,
        AnalysisSection.amounts,
        AnalysisSection.dates,
        AnalysisSection.requiredDocuments,
        AnalysisSection.instructions,
        AnalysisSection.detailedExplanation,
        AnalysisSection.extractedText,
      ]);
    });

    test('keeps the order when sections in the middle are missing', () {
      final full = invoiceAnalysis();
      final result = useCase(
        analysis: DocumentAnalysis(
          sessionId: full.sessionId,
          status: full.status,
          kind: full.kind,
          title: full.title,
          kindConfidence: full.kindConfidence,
          summary: full.summary,
          dates: full.dates,
          warnings: full.warnings,
        ),
        extractedText: _ocrText,
      );

      expect(result.sections, [
        AnalysisSection.header,
        AnalysisSection.summary,
        AnalysisSection.warnings,
        AnalysisSection.dates,
        AnalysisSection.detailedExplanation,
        AnalysisSection.extractedText,
      ]);
    });

    test('drops every empty section', () {
      final result = useCase(
        analysis: unsupportedAnalysis,
        extractedText: _ocrText,
      );

      expect(result.sections, [
        AnalysisSection.header,
        AnalysisSection.extractedText,
      ]);
    });

    test('keeps the header even when nothing else was understood', () {
      final result = useCase(analysis: unsupportedAnalysis, extractedText: '');

      expect(result.sections, [AnalysisSection.header]);
    });

    test('shows the extracted text whenever there is any', () {
      final result = useCase(
        analysis: unsupportedAnalysis,
        extractedText: _ocrText,
      );

      expect(result.has(AnalysisSection.extractedText), isTrue);
      expect(result.extractedText, _ocrText);
    });

    test('treats whitespace-only summary text as absent', () {
      final result = useCase(
        analysis: invoiceAnalysis(
          summary: const AnalysisSummary(short: '   ', detailed: '\n  '),
        ),
        extractedText: _ocrText,
      );

      expect(result.has(AnalysisSection.summary), isFalse);
      expect(result.has(AnalysisSection.detailedExplanation), isFalse);
    });

    test('splits the two summary blocks — short leads, detailed explains', () {
      final result = useCase(
        analysis: invoiceAnalysis(
          summary: const AnalysisSummary(short: 'خلاصة', detailed: ''),
        ),
        extractedText: _ocrText,
      );

      expect(result.has(AnalysisSection.summary), isTrue);
      expect(result.has(AnalysisSection.detailedExplanation), isFalse);
    });

    test('carries the analysis through untouched', () {
      final analysis = invoiceAnalysis();
      final result = useCase(analysis: analysis, extractedText: _ocrText);

      expect(result.analysis, same(analysis));
    });

    test('a partial result keeps the sections it did understand', () {
      final result = useCase(
        analysis: invoiceAnalysis(status: AnalysisStatus.partial),
        extractedText: _ocrText,
      );

      expect(result.sections, hasLength(AnalysisSection.values.length));
    });
  });
}
