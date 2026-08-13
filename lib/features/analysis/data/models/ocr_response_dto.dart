import '../../../ocr/domain/entities/amount_candidate.dart';
import '../../../ocr/domain/entities/date_candidate.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../../../ocr/domain/entities/normalized_ocr_text.dart';
import '../../../ocr/domain/entities/phone_candidate.dart';
import '../../../ocr/domain/entities/reference_candidate.dart';
import '../../../ocr/domain/entities/time_candidate.dart';
import 'amount_candidate_dto.dart';
import 'candidates_dto.dart';
import 'date_candidate_dto.dart';
import 'phone_candidate_dto.dart';
import 'reference_candidate_dto.dart';
import 'time_candidate_dto.dart';

/// Parses the `ocr-document` endpoint's response body (F14) into an
/// [ExtractionResult].
///
/// Sibling to `AnalysisResponseDto`, not a variant of it: this endpoint never
/// produces a `DocumentAnalysis` — no Groq is involved — so it gets its own
/// parser instead of a branch in the one that reads analyze-document bodies.
final class OcrResponseDto {
  const OcrResponseDto({
    required this.schemaVersion,
    required this.sessionId,
    required this.ocrText,
    required this.detectedLanguages,
    required this.candidates,
  });

  factory OcrResponseDto.fromJson(Map<String, dynamic> json) {
    return OcrResponseDto(
      schemaVersion: json['schema_version'] as String,
      sessionId: json['session_id'] as String,
      ocrText: json['ocr_text'] as String,
      detectedLanguages: (json['detected_languages'] as List<dynamic>)
          .cast<String>(),
      candidates: CandidatesDto.fromJson(
        json['candidates'] as Map<String, dynamic>,
      ),
    );
  }

  final String schemaVersion;
  final String sessionId;
  final String ocrText;
  final List<String> detectedLanguages;
  final CandidatesDto candidates;

  /// Turns the wire shape into the same [ExtractionResult] the offline
  /// (Tesseract) pipeline produces, so the review screen and the eventual
  /// `AnalysisRequest` builder can treat either origin identically.
  ///
  /// The server text is already cleaned (Azure OCR + backend normalization),
  /// so original and cleaned are the same string here — unlike the offline
  /// route, where [NormalizedOcrText] carries the pre- and post-normalization
  /// text side by side.
  ExtractionResult toExtractionResult() {
    return ExtractionResult(
      text: NormalizedOcrText(originalText: ocrText, cleanedText: ocrText),
      detectedLanguages: detectedLanguages,
      dates: candidates.dates.map(_dateToEntity).toList(),
      times: candidates.times.map(_timeToEntity).toList(),
      amounts: candidates.amounts.map(_amountToEntity).toList(),
      phones: candidates.phones.map(_phoneToEntity).toList(),
      references: candidates.references.map(_referenceToEntity).toList(),
    );
  }
}

// No `toEntity()` exists on the candidate DTOs today — only `fromJson` and
// `fromEntity` (the wire→entity direction has never been needed before this
// endpoint, since every other candidate DTO flows entity→wire). Written here
// rather than added to the DTOs themselves, since this is the one place that
// needs it.

DateCandidate _dateToEntity(DateCandidateDto dto) => DateCandidate(
  rawText: dto.rawText,
  normalizedDate: _parseIsoDate(dto.normalizedDate),
  isAmbiguous: dto.isAmbiguous,
);

TimeCandidate _timeToEntity(TimeCandidateDto dto) => TimeCandidate(
  rawText: dto.rawText,
  hour: dto.hour,
  minute: dto.minute,
  isAmbiguous: dto.isAmbiguous,
);

AmountCandidate _amountToEntity(AmountCandidateDto dto) => AmountCandidate(
  rawText: dto.rawText,
  value: dto.value,
  currency: dto.currency,
  isAmbiguous: dto.isAmbiguous,
);

PhoneCandidate _phoneToEntity(PhoneCandidateDto dto) => PhoneCandidate(
  rawText: dto.rawText,
  normalizedNumber: dto.normalizedNumber,
  isAmbiguous: dto.isAmbiguous,
);

ReferenceCandidate _referenceToEntity(ReferenceCandidateDto dto) =>
    ReferenceCandidate(
      rawText: dto.rawText,
      value: dto.value,
      isAmbiguous: dto.isAmbiguous,
    );

/// Parses `normalized_date` (§29 `yyyy-MM-dd`, the same wire format
/// [DateCandidateDto.fromEntity] writes) back into the local-midnight
/// [DateTime] the extractors produce. `null` when Azure/the extractor found
/// no parseable date, or the string is malformed.
DateTime? _parseIsoDate(String? iso) {
  if (iso == null) return null;
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
