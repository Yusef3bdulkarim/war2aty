final class SummaryDto {
  const SummaryDto({required this.short, required this.detailed});

  factory SummaryDto.fromJson(Map<String, dynamic> json) {
    return SummaryDto(
      short: json['short'] as String,
      detailed: json['detailed'] as String,
    );
  }

  final String short;
  final String detailed;

  Map<String, dynamic> toJson() => {'short': short, 'detailed': detailed};
}
