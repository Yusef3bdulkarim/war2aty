import '../entities/extraction_result.dart';
import '../entities/ocr_result.dart';
import '../services/amount_extractor.dart';
import '../services/date_extractor.dart';
import '../services/phone_extractor.dart';
import '../services/reference_extractor.dart';
import '../services/text_normalizer.dart';
import '../services/time_extractor.dart';

/// Normalizes raw OCR text then runs all five extractors, producing a
/// complete [ExtractionResult].
///
/// This is the second use case the [OcrProcessingCubit] calls, after
/// [ExtractDocumentText] succeeds.
final class ExtractCandidates {
  const ExtractCandidates({
    required TextNormalizer normalizer,
    required DateExtractor dateExtractor,
    required TimeExtractor timeExtractor,
    required AmountExtractor amountExtractor,
    required PhoneExtractor phoneExtractor,
    required ReferenceExtractor referenceExtractor,
  }) : _normalizer = normalizer,
       _dateExtractor = dateExtractor,
       _timeExtractor = timeExtractor,
       _amountExtractor = amountExtractor,
       _phoneExtractor = phoneExtractor,
       _referenceExtractor = referenceExtractor;

  final TextNormalizer _normalizer;
  final DateExtractor _dateExtractor;
  final TimeExtractor _timeExtractor;
  final AmountExtractor _amountExtractor;
  final PhoneExtractor _phoneExtractor;
  final ReferenceExtractor _referenceExtractor;

  ExtractionResult call(OcrResult ocrResult) {
    final normalized = _normalizer.normalize(ocrResult);
    final cleaned = normalized.cleanedText;

    return ExtractionResult(
      text: normalized,
      dates: _dateExtractor.extract(cleaned),
      times: _timeExtractor.extract(cleaned),
      amounts: _amountExtractor.extract(cleaned),
      phones: _phoneExtractor.extract(cleaned),
      references: _referenceExtractor.extract(cleaned),
    );
  }
}
