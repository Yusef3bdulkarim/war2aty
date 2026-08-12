/// Wire representation of a §30 v2 `phones[]` item (API_CONTRACT §30, F13
/// locked decision #6, F13-T17).
///
/// Unlike `PhoneCandidateDto` — the request-side OCR candidate this is
/// verified against — this is the response shape: `rawValue`/`value` are
/// required, non-null strings, and `needsUserReview` is the only trust
/// signal that crosses the wire; `verificationStatus` stays backend-only.
final class PhoneItemDto {
  const PhoneItemDto({
    required this.rawValue,
    required this.value,
    required this.needsUserReview,
  });

  factory PhoneItemDto.fromJson(Map<String, dynamic> json) {
    return PhoneItemDto(
      rawValue: json['rawValue'] as String,
      value: json['value'] as String,
      needsUserReview: json['needsUserReview'] as bool,
    );
  }

  final String rawValue;
  final String value;
  final bool needsUserReview;

  // Both keys are camelCase on the wire, unlike the rest of the response
  // body (API_CONTRACT §30 v2).
  Map<String, dynamic> toJson() => {
    'rawValue': rawValue,
    'value': value,
    'needsUserReview': needsUserReview,
  };
}
