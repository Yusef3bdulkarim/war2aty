/// Wire representation of the API error body (API_CONTRACT §31).
///
/// Shared by every endpoint — analyze-document and get-usage answer failures
/// with the same envelope, so this lives in `core/` rather than inside a
/// feature (CLAUDE.md §2).
///
/// [message] is English and for debugging only — never surface it to the user
/// and never log it alongside document content. Mapping [code] to an
/// `AppFailure` (and unknown codes to `AnalysisServiceFailure`) happens in the
/// repository.
final class ApiErrorDto {
  const ApiErrorDto({required this.code, required this.message, this.details});

  /// Parses the `{ "error": { ... } }` envelope.
  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDto.fromErrorObject(json['error'] as Map<String, dynamic>);
  }

  factory ApiErrorDto.fromErrorObject(Map<String, dynamic> error) {
    return ApiErrorDto(
      code: error['code'] as String,
      message: error['message'] as String,
      details: error['details'] == null
          ? null
          : ApiErrorDetailsDto.fromJson(
              error['details'] as Map<String, dynamic>,
            ),
    );
  }

  /// Raw wire enum — see the error-code table in §31.
  final String code;
  final String message;
  final ApiErrorDetailsDto? details;

  Map<String, dynamic> toJson() => {
    'error': {
      'code': code,
      'message': message,
      if (details != null) 'details': details!.toJson(),
    },
  };
}

final class ApiErrorDetailsDto {
  const ApiErrorDetailsDto({this.resetAt});

  factory ApiErrorDetailsDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetailsDto(resetAt: json['reset_at'] as String?);
  }

  /// ISO-8601 Cairo-midnight timestamp sent with `DAILY_LIMIT_REACHED`.
  final String? resetAt;

  Map<String, dynamic> toJson() => {if (resetAt != null) 'reset_at': resetAt};
}
