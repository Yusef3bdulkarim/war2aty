import '../../../ocr/domain/entities/date_candidate.dart';

final class DateCandidateDto {
  const DateCandidateDto({
    required this.rawText,
    this.normalizedDate,
    required this.isAmbiguous,
  });

  factory DateCandidateDto.fromJson(Map<String, dynamic> json) {
    return DateCandidateDto(
      rawText: json['raw_text'] as String,
      normalizedDate: json['normalized_date'] as String?,
      isAmbiguous: json['is_ambiguous'] as bool,
    );
  }

  factory DateCandidateDto.fromEntity(DateCandidate entity) {
    final date = entity.normalizedDate;
    String? iso;
    if (date != null) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      iso = '$y-$m-$d';
    }
    return DateCandidateDto(
      rawText: entity.rawText,
      normalizedDate: iso,
      isAmbiguous: entity.isAmbiguous,
    );
  }

  final String rawText;
  final String? normalizedDate;
  final bool isAmbiguous;

  Map<String, dynamic> toJson() => {
    'raw_text': rawText,
    'normalized_date': normalizedDate,
    'is_ambiguous': isAmbiguous,
  };
}
