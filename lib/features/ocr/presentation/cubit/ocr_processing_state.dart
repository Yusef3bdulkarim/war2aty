import '../../domain/entities/extraction_result.dart';

/// States for the OCR processing pipeline.
sealed class OcrProcessingState {
  const OcrProcessingState();
}

/// The pipeline is running (preprocess → OCR → normalize → extract).
final class OcrProcessing extends OcrProcessingState {
  const OcrProcessing();
}

/// The OCR engine failed or produced garbled output.
final class OcrError extends OcrProcessingState {
  const OcrError();
}

/// The OCR engine succeeded but found no usable text.
final class OcrNoText extends OcrProcessingState {
  const OcrNoText();
}

/// The full pipeline completed. [result] holds the normalized text and
/// all extracted candidates.
final class OcrCompleted extends OcrProcessingState {
  const OcrCompleted(this.result);

  final ExtractionResult result;

  @override
  bool operator ==(Object other) =>
      other is OcrCompleted && other.result == result;

  @override
  int get hashCode => result.hashCode;
}
