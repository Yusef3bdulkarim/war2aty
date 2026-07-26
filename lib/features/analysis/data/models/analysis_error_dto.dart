/// Wire representation of the analyze-document error body (API_CONTRACT §31).
///
/// [message] is English and for debugging only — never surface it to the user
/// and never log it alongside document content. Mapping [code] to an
/// `AppFailure` (and unknown codes to `AnalysisServiceFailure`) happens in the
/// repository.
final class AnalysisErrorDto {
  const AnalysisErrorDto({
    required this.code,
    required this.message,
    this.details,
  });

  /// Parses the `{ "error": { ... } }` envelope.
  factory AnalysisErrorDto.fromJson(Map<String, dynamic> json) {
    return AnalysisErrorDto.fromErrorObject(
      json['error'] as Map<String, dynamic>,
    );
  }

  factory AnalysisErrorDto.fromErrorObject(Map<String, dynamic> error) {
    return AnalysisErrorDto(
      code: error['code'] as String,
      message: error['message'] as String,
      details: error['details'] == null
          ? null
          : AnalysisErrorDetailsDto.fromJson(
              error['details'] as Map<String, dynamic>,
            ),
    );
  }

  /// Raw wire enum — see the error-code table in §31.
  final String code;
  final String message;
  final AnalysisErrorDetailsDto? details;

  Map<String, dynamic> toJson() => {
    'error': {
      'code': code,
      'message': message,
      if (details != null) 'details': details!.toJson(),
    },
  };
}

final class AnalysisErrorDetailsDto {
  const AnalysisErrorDetailsDto({this.resetAt});

  factory AnalysisErrorDetailsDto.fromJson(Map<String, dynamic> json) {
    return AnalysisErrorDetailsDto(resetAt: json['reset_at'] as String?);
  }

  /// ISO-8601 Cairo-midnight timestamp sent with `DAILY_LIMIT_REACHED`.
  final String? resetAt;

  Map<String, dynamic> toJson() => {if (resetAt != null) 'reset_at': resetAt};
}
