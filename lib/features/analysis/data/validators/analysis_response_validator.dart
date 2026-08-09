import '../../../../core/documents/document_analysis.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../mappers/analysis_response_mapper.dart';
import '../models/analysis_response_dto.dart';

/// Response schema versions this build can read (API_CONTRACT §30).
const kSupportedAnalysisSchemaVersions = {'1.0'};

/// Turns a decoded analyze-document body into a [DocumentAnalysis], or a
/// failure — without ever throwing.
///
/// This is the only place raw wire data becomes domain data. Everything above
/// it works with a [Result], so a malformed, truncated or unexpected payload
/// shows the user an Arabic error instead of crashing the result screen.
///
/// It does not judge the *outcome*: a `status: "unsupported"` body is a valid
/// response and comes back as [Ok]. Turning that into an
/// `UnsupportedDocumentFailure` is the repository's call (§31 rule 6).
final class AnalysisResponseValidator {
  const AnalysisResponseValidator();

  /// [decodedBody] is whatever `jsonDecode` produced — not assumed to be a
  /// JSON object, let alone a well-formed one.
  Result<DocumentAnalysis, AppFailure> validate(Object? decodedBody) {
    if (decodedBody is! Map<String, dynamic>) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    // Checked before parsing: an unreadable version means the rest of the body
    // can't be trusted to have the shape the DTOs expect.
    //
    // A newer schema is treated the same as a broken one. The server gates old
    // builds with `UNSUPPORTED_APP_VERSION` (§31) long before it would send a
    // body this build can't read, so there is no separate "update the app"
    // path to take here.
    final version = decodedBody['schema_version'];
    if (version is! String ||
        !kSupportedAnalysisSchemaVersions.contains(version)) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    try {
      return Ok(AnalysisResponseDto.fromJson(decodedBody).toDomain());
    } catch (_) {
      // Deliberately catch-all: missing keys surface as TypeError, bad enums
      // and dates as AnalysisMappingException, and anything the schema didn't
      // anticipate as something else entirely. The caught object is dropped
      // rather than logged — it can quote document content (privacy §7).
      return const Err(InvalidAnalysisResponseFailure());
    }
  }
}
