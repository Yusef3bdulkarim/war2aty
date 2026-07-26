import '../../../ocr/domain/entities/amount_candidate.dart';

final class AmountCandidateDto {
  const AmountCandidateDto({
    required this.rawText,
    this.value,
    this.currency,
    required this.isAmbiguous,
  });

  factory AmountCandidateDto.fromJson(Map<String, dynamic> json) {
    return AmountCandidateDto(
      rawText: json['raw_text'] as String,
      value: (json['value'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      isAmbiguous: json['is_ambiguous'] as bool,
    );
  }

  factory AmountCandidateDto.fromEntity(AmountCandidate entity) {
    return AmountCandidateDto(
      rawText: entity.rawText,
      value: entity.value,
      currency: entity.currency,
      isAmbiguous: entity.isAmbiguous,
    );
  }

  final String rawText;
  final double? value;
  final String? currency;
  final bool isAmbiguous;

  Map<String, dynamic> toJson() => {
    'raw_text': rawText,
    'value': value,
    'currency': currency,
    'is_ambiguous': isAmbiguous,
  };
}
