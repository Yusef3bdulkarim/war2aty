import '../../../../core/error/app_failure.dart';
import '../../../../core/papers/paper_explanation.dart';
import '../../../../core/result/result.dart';
import '../mappers/explain_response_mapper.dart';
import '../models/explain_response_dto.dart';

const kSupportedExplainSchemaVersions = {'1.0'};

final class ExplainResponseValidator {
  const ExplainResponseValidator();

  Result<PaperExplanation, AppFailure> validate(Object? decodedBody) {
    if (decodedBody is! Map<String, dynamic>) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    final version = decodedBody['explain_schema_version'];
    if (version is! String ||
        !kSupportedExplainSchemaVersions.contains(version)) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    try {
      return Ok(ExplainResponseDto.fromJson(decodedBody).toDomain());
    } catch (_) {
      return const Err(InvalidAnalysisResponseFailure());
    }
  }
}
