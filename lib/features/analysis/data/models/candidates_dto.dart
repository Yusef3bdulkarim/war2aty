import 'amount_candidate_dto.dart';
import 'date_candidate_dto.dart';
import 'phone_candidate_dto.dart';
import 'reference_candidate_dto.dart';
import 'time_candidate_dto.dart';

final class CandidatesDto {
  const CandidatesDto({
    this.dates = const [],
    this.times = const [],
    this.amounts = const [],
    this.phones = const [],
    this.references = const [],
  });

  factory CandidatesDto.fromJson(Map<String, dynamic> json) {
    return CandidatesDto(
      dates: (json['dates'] as List<dynamic>)
          .map((e) => DateCandidateDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      times: (json['times'] as List<dynamic>)
          .map((e) => TimeCandidateDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      amounts: (json['amounts'] as List<dynamic>)
          .map((e) => AmountCandidateDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      phones: (json['phones'] as List<dynamic>)
          .map((e) => PhoneCandidateDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      references: (json['references'] as List<dynamic>)
          .map((e) => ReferenceCandidateDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<DateCandidateDto> dates;
  final List<TimeCandidateDto> times;
  final List<AmountCandidateDto> amounts;
  final List<PhoneCandidateDto> phones;
  final List<ReferenceCandidateDto> references;

  Map<String, dynamic> toJson() => {
    'dates': dates.map((e) => e.toJson()).toList(),
    'times': times.map((e) => e.toJson()).toList(),
    'amounts': amounts.map((e) => e.toJson()).toList(),
    'phones': phones.map((e) => e.toJson()).toList(),
    'references': references.map((e) => e.toJson()).toList(),
  };
}
