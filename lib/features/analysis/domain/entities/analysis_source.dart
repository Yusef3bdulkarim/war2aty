import '../../../capture/domain/entities/captured_photo.dart';
import '../../../ocr/domain/entities/extraction_result.dart';

/// What one analysis run is built from — the offline/online split of F13
/// locked decision #1, carried into [AnalysisResultCubit].
sealed class AnalysisSource {
  const AnalysisSource();
}

/// Offline route: local OCR already ran (F04/F05, unchanged by F13).
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

/// Online route: OCR is skipped entirely — [photo] is read server-side
/// instead (F13 locked decision #1). Expected to already be
/// perspective-corrected (F13-T12), never the raw sensor frame.
final class ImageAnalysisSource extends AnalysisSource {
  const ImageAnalysisSource(this.photo);

  final CapturedPhoto photo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageAnalysisSource && other.photo == photo;

  @override
  int get hashCode => photo.hashCode;
}
