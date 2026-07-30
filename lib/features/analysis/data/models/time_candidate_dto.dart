import '../../../ocr/domain/entities/time_candidate.dart';

final class TimeCandidateDto {
  const TimeCandidateDto({
    required this.rawText,
    required this.hour,
    required this.minute,
    required this.isAmbiguous,
  });

  factory TimeCandidateDto.fromJson(Map<String, dynamic> json) {
    return TimeCandidateDto(
      rawText: json['raw_text'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      isAmbiguous: json['is_ambiguous'] as bool,
    );
  }

  factory TimeCandidateDto.fromEntity(TimeCandidate entity) {
    return TimeCandidateDto(
      rawText: entity.rawText,
      hour: entity.hour,
      minute: entity.minute,
      isAmbiguous: entity.isAmbiguous,
    );
  }

  final String rawText;
  final int hour;
  final int minute;
  final bool isAmbiguous;

  Map<String, dynamic> toJson() => {
    'raw_text': rawText,
    'hour': hour,
    'minute': minute,
    'is_ambiguous': isAmbiguous,
  };
}
