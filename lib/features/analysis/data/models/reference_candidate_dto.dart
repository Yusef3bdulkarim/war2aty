import '../../../ocr/domain/entities/reference_candidate.dart';

final class ReferenceCandidateDto {
  const ReferenceCandidateDto({
    required this.rawText,
    required this.value,
    required this.isAmbiguous,
  });

  factory ReferenceCandidateDto.fromJson(Map<String, dynamic> json) {
    return ReferenceCandidateDto(
      rawText: json['raw_text'] as String,
      value: json['value'] as String,
      isAmbiguous: json['is_ambiguous'] as bool,
    );
  }

  factory ReferenceCandidateDto.fromEntity(ReferenceCandidate entity) {
    return ReferenceCandidateDto(
      rawText: entity.rawText,
      value: entity.value,
      isAmbiguous: entity.isAmbiguous,
    );
  }

  final String rawText;
  final String value;
  final bool isAmbiguous;

  Map<String, dynamic> toJson() => {
    'raw_text': rawText,
    'value': value,
    'is_ambiguous': isAmbiguous,
  };
}
