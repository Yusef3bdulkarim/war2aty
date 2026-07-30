import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/documents/analysis_status.dart';
import '../../../../core/documents/document_analysis.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/identity/installation_id_provider.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_event.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/network_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/repositories/analysis_repository.dart';
import '../datasources/analysis_remote_data_source.dart';
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
    } on DioException catch (exception) {
      // The transport seam (§31 rule 5): "you are offline" and "this is taking
      // too long" suggest different actions to the user, so they must not
      // collapse into one generic error.
      return Err(failureFromDioException(exception));
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } on Object {
      // Anything a datasource can still throw — a mock's asset load, a JSON
      // decode. The caught object is dropped rather than logged: it can quote
      // the payload that broke, and that payload is the document (§7).
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      // The status is passed too: the Supabase gateway rejects an expired token
      // before our function runs, so its 401 body is not a §31 envelope.
      return Err(
        failureFromErrorBody(response.body, statusCode: response.statusCode),
      );
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
