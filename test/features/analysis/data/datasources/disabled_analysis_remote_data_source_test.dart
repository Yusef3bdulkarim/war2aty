import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/analysis/data/datasources/disabled_analysis_remote_data_source.dart';
import 'package:war2aty/features/analysis/data/mappers/analysis_error_mapper.dart';
import 'package:war2aty/features/analysis/data/models/analysis_request_dto.dart';
import 'package:war2aty/features/analysis/data/models/candidates_dto.dart';

const _request = AnalysisRequestDto(
  schemaVersion: '1.0',
  sessionId: 'session-1',
  installationId: 'install-1',
  appVersion: '1.0.0',
  ocrText: 'فاتورة كهرباء',
  detectedLanguages: ['ar'],
  candidates: CandidatesDto(),
);

void main() {
  group('DisabledAnalysisRemoteDataSource', () {
    test('refuses instead of inventing a result', () async {
      const source = DisabledAnalysisRemoteDataSource();

      final response = await source.analyze(_request);

      expect(response.isSuccess, isFalse);
      expect(response.statusCode, 503);
    });

    test('its body maps to the maintenance failure', () async {
      const source = DisabledAnalysisRemoteDataSource();

      final response = await source.analyze(_request);

      expect(
        failureFromErrorBody(response.body),
        isA<AnalysisDisabledFailure>(),
      );
    });
  });
}
