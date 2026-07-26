import '../../../ocr/domain/entities/phone_candidate.dart';

final class PhoneCandidateDto {
  const PhoneCandidateDto({
    required this.rawText,
    required this.normalizedNumber,
    required this.isAmbiguous,
  });

  factory PhoneCandidateDto.fromJson(Map<String, dynamic> json) {
    return PhoneCandidateDto(
      rawText: json['raw_text'] as String,
      normalizedNumber: json['normalized_number'] as String,
      isAmbiguous: json['is_ambiguous'] as bool,
    );
  }

  factory PhoneCandidateDto.fromEntity(PhoneCandidate entity) {
    return PhoneCandidateDto(
      rawText: entity.rawText,
      normalizedNumber: entity.normalizedNumber,
      isAmbiguous: entity.isAmbiguous,
    );
  }

  final String rawText;
  final String normalizedNumber;
  final bool isAmbiguous;

  Map<String, dynamic> toJson() => {
    'raw_text': rawText,
    'normalized_number': normalizedNumber,
    'is_ambiguous': isAmbiguous,
  };
}
