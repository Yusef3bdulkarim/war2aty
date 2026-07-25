import 'dart:async';

import '../../../../core/error/app_failure.dart';
import '../../../../core/identity/installation_id_provider.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_event.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/entities/analysis_status.dart';
import '../../domain/entities/document_analysis.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../datasources/analysis_remote_data_source.dart';
import '../mappers/analysis_error_mapper.dart';
import '../models/amount_candidate_dto.dart';
import '../models/analysis_request_dto.dart';
import '../models/candidates_dto.dart';
import '../models/date_candidate_dto.dart';
import '../models/phone_candidate_dto.dart';
import '../models/reference_candidate_dto.dart';
import '../models/time_candidate_dto.dart';
import '../validators/analysis_response_validator.dart';

/// Request contract version this build speaks (API_CONTRACT §29).
const String kAnalysisRequestSchemaVersion = '1.0';

/// The one [AnalysisRepository] implementation.
///
/// Builds the request from the OCR result, hands it to whichever
/// [AnalysisRemoteDataSource] is registered — mock today, the Edge Function
/// client from F06 — and turns every outcome into a `Result`. Nothing throws
/// past this class.
final class DefaultAnalysisRepository implements AnalysisRepository {
  const DefaultAnalysisRepository({
    required AnalysisRemoteDataSource dataSource,
    required InstallationIdProvider installationId,
    required AppLogger logger,
    required String appVersion,
    AnalysisResponseValidator validator = const AnalysisResponseValidator(),
  }) : _dataSource = dataSource,
       _installationId = installationId,
       _logger = logger,
       _appVersion = appVersion,
       _validator = validator;

  final AnalysisRemoteDataSource _dataSource;
  final InstallationIdProvider _installationId;
  final AppLogger _logger;
  final String _appVersion;
  final AnalysisResponseValidator _validator;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    final result = await _analyze(request);

    if (result case Err(:final failure)) {
      _logger.failure(
        failure,
        stage: LogStage.analyze,
        sessionId: request.sessionId,
      );
    }
    return result;
  }

  Future<Result<DocumentAnalysis, AppFailure>> _analyze(
    AnalysisRequest request,
  ) async {
    final identity = await _installationId.getOrCreate();
    if (identity case Err(:final failure)) return Err(failure);

    final dto = _buildRequest(request, identity.valueOrNull!);

    final AnalysisApiResponse response;
    try {
      response = await _dataSource.analyze(dto);
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } catch (_) {
      // No HTTP client yet, so there are no transport exception types to
      // discriminate on. F06 refines this into NoInternet vs Timeout (§31
      // rule 5) when the real datasource lands.
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      return Err(failureFromErrorBody(response.body));
    }

    return _validator.validate(response.body).flatMap(_rejectUnsupported);
  }

  /// A 200 carrying `status: "unsupported"` is a valid response but not a
  /// usable result (§31 rule 6). The result screen shows the OCR-only
  /// fallback, and the attempt does not count against the daily limit.
  Result<DocumentAnalysis, AppFailure> _rejectUnsupported(
    DocumentAnalysis analysis,
  ) {
    if (analysis.status == AnalysisStatus.unsupported) {
      return const Err(UnsupportedDocumentFailure());
    }
    return Ok(analysis);
  }

  /// Assembles the wire request. The image never appears here — [request]
  /// has no field for it (privacy §7).
  AnalysisRequestDto _buildRequest(
    AnalysisRequest request,
    String installationId,
  ) {
    final extraction = request.extraction;

    return AnalysisRequestDto(
      schemaVersion: kAnalysisRequestSchemaVersion,
      sessionId: request.sessionId,
      installationId: installationId,
      appVersion: _appVersion,
      // The cleaned text, not the raw OCR output: normalised digits and
      // whitespace are what the model is prompted against.
      ocrText: extraction.text.cleanedText,
      detectedLanguages: request.detectedLanguages,
      candidates: CandidatesDto(
        dates: extraction.dates.map(DateCandidateDto.fromEntity).toList(),
        times: extraction.times.map(TimeCandidateDto.fromEntity).toList(),
        amounts: extraction.amounts.map(AmountCandidateDto.fromEntity).toList(),
        phones: extraction.phones.map(PhoneCandidateDto.fromEntity).toList(),
        references: extraction.references
            .map(ReferenceCandidateDto.fromEntity)
            .toList(),
      ),
    );
  }
}
