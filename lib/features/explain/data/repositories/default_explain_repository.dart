import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/config/runtime_config_store.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/identity/installation_id_provider.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_event.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/network_failure_mapper.dart';
import '../../../../core/papers/explain_outcome.dart';
import '../../../../core/result/result.dart';
import '../../../capture/domain/entities/captured_photo.dart';
import '../../domain/repositories/explain_repository.dart';
import '../datasources/explain_remote_data_source.dart';
import '../models/explain_request_dto.dart';
import '../validators/explain_response_validator.dart';

typedef ImageBytesReader = Future<Uint8List> Function(String path);

Future<Uint8List> _readFileBytes(String path) => File(path).readAsBytes();

String _defaultGenerateId() => const Uuid().v4();

final class DefaultExplainRepository implements ExplainRepository {
  const DefaultExplainRepository({
    required ExplainRemoteDataSource dataSource,
    required InstallationIdProvider installationId,
    required AppLogger logger,
    required String appVersion,
    required RuntimeConfigStore config,
    ExplainResponseValidator validator = const ExplainResponseValidator(),
    ImageBytesReader readImageBytes = _readFileBytes,
    IdGenerator generateSessionId = _defaultGenerateId,
  }) : _dataSource = dataSource,
       _installationId = installationId,
       _logger = logger,
       _appVersion = appVersion,
       _config = config,
       _validator = validator,
       _readImageBytes = readImageBytes,
       _generateSessionId = generateSessionId;

  final ExplainRemoteDataSource _dataSource;
  final InstallationIdProvider _installationId;
  final AppLogger _logger;
  final String _appVersion;
  final RuntimeConfigStore _config;
  final ExplainResponseValidator _validator;
  final ImageBytesReader _readImageBytes;
  final IdGenerator _generateSessionId;

  @override
  Future<Result<ExplainOutcome, AppFailure>> explain(
    CapturedPhoto photo,
  ) async {
    final sessionId = _generateSessionId();
    final result = await _explain(photo, sessionId);

    if (result case Err(:final failure)) {
      _logger.failure(failure, stage: LogStage.explain, sessionId: sessionId);
    }
    return result;
  }

  Future<Result<ExplainOutcome, AppFailure>> _explain(
    CapturedPhoto photo,
    String sessionId,
  ) async {
    final identity = await _installationId.getOrCreate();
    if (identity case Err(:final failure)) return Err(failure);

    final config = _config.current;

    final ExplainRequestDto dto;
    try {
      dto = await _buildRequest(
        photo,
        identity.valueOrNull!,
        sessionId,
        config.explainSchemaVersion,
      );
    } on Object {
      return const Err(ImageProcessingFailure());
    }

    final ExplainApiResponse response;
    try {
      response = await _dataSource.explain(dto, timeout: config.explainTimeout);
    } on DioException catch (exception) {
      return Err(failureFromDioException(exception));
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } on Object {
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      return Err(
        failureFromErrorBody(response.body, statusCode: response.statusCode),
      );
    }

    return _validator
        .validate(response.body)
        .map(
          (explanation) => (
            explanation: explanation,
            sessionId: sessionId,
            explainSchemaVersion: dto.explainSchemaVersion,
          ),
        );
  }

  Future<ExplainRequestDto> _buildRequest(
    CapturedPhoto photo,
    String installationId,
    String sessionId,
    String explainSchemaVersion,
  ) async {
    final bytes = await _readImageBytes(photo.path);
    final encoded = await Isolate.run(() => base64Encode(bytes));

    return ExplainRequestDto(
      explainSchemaVersion: explainSchemaVersion,
      sessionId: sessionId,
      installationId: installationId,
      appVersion: _appVersion,
      image: ExplainImageDto(data: encoded, mimeType: _mimeTypeFor(photo.path)),
    );
  }

  String _mimeTypeFor(String path) =>
      p.extension(path).toLowerCase() == '.png' ? 'image/png' : 'image/jpeg';
}
