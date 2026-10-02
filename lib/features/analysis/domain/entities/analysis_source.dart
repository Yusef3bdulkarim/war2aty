import '../../../ocr/domain/entities/extraction_result.dart';

/// What one analysis run is built from, carried into [AnalysisResultCubit].
///
/// Every analysis is text (F20-T19): both routes reach `/result` only after
/// the OCR review, whether the page was read online or on the device. The
/// image variant F13 added went with the dead image path; the sealed type is
/// kept so a new source is a compile-checked addition, not a signature change.
sealed class AnalysisSource {
  const AnalysisSource();
}

/// The reviewed OCR result — read on the device or online, then approved by
/// the user on the OCR review screen.
final class OcrAnalysisSource extends AnalysisSource {
  const OcrAnalysisSource(this.extraction);

  final ExtractionResult extraction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrAnalysisSource && other.extraction == extraction;

  @override
  int get hashCode => extraction.hashCode;
}
