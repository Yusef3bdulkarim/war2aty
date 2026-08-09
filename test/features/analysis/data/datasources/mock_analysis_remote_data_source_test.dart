import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/features/analysis/data/datasources/analysis_fixture.dart';
import 'package:war2aty/features/analysis/data/datasources/mock_analysis_remote_data_source.dart';
import 'package:war2aty/features/analysis/data/models/analysis_request_dto.dart';
import 'package:war2aty/features/analysis/data/models/candidates_dto.dart';
import 'package:war2aty/features/analysis/data/validators/analysis_response_validator.dart';

/// Reads the real fixture files, standing in for `rootBundle`.
Future<String> _loadFromDisk(String key) async => File(key).readAsString();

AnalysisRequestDto _request(String ocrText) => AnalysisRequestDto(
  schemaVersion: '1.0',
  sessionId: 'session-1',
  installationId: 'install-1',
  appVersion: '1.0.0',
  ocrText: ocrText,
  detectedLanguages: const ['ar'],
  candidates: const CandidatesDto(),
);

MockAnalysisRemoteDataSource _source({AnalysisFixture? forced}) =>
    MockAnalysisRemoteDataSource(
      loadAsset: _loadFromDisk,
      forcedFixture: forced,
      latency: Duration.zero,
    );

void main() {
  group('fixtureForText', () {
    test('picks the fixture matching the document wording', () {
      expect(
        fixtureForText('فاتورة كهرباء عن شهر مارس'),
        AnalysisFixture.invoice,
      );
      expect(
        fixtureForText('موعد كشف في العيادة'),
        AnalysisFixture.appointment,
      );
      expect(
        fixtureForText('إخطار من مصلحة الضرائب'),
        AnalysisFixture.government,
      );
      expect(
        fixtureForText('نتيجة الثانوية العامة رقم الجلوس'),
        AnalysisFixture.exam,
      );
    });

    test('falls back to the invoice slice for unrecognised text', () {
      expect(fixtureForText('كلام مالوش لازمة'), AnalysisFixture.invoice);
      expect(fixtureForText(''), AnalysisFixture.invoice);
    });
  });

  group('analyze', () {
    test('answers 200 with a body the validator accepts', () async {
      final response = await _source().analyze(_request('فاتورة كهرباء'));

      expect(response.statusCode, 200);
      expect(response.isSuccess, isTrue);

      const validator = AnalysisResponseValidator();
      final analysis = validator.validate(response.body).valueOrNull;
      expect(analysis, isNotNull);
      expect(analysis!.kind, DocumentKind.invoice);
    });

    test('serves the fixture the text points at', () async {
      final response = await _source().analyze(_request('موعد كشف'));

      const validator = AnalysisResponseValidator();
      final analysis = validator.validate(response.body).valueOrNull!;
      expect(analysis.kind, DocumentKind.appointment);
    });

    test('honours a forced fixture over the text', () async {
      final response = await _source(
        forced: AnalysisFixture.unsupported,
      ).analyze(_request('فاتورة كهرباء'));

      const validator = AnalysisResponseValidator();
      final analysis = validator.validate(response.body).valueOrNull!;
      expect(analysis.status, AnalysisStatus.unsupported);
    });

    test('can serve every fixture', () async {
      for (final fixture in AnalysisFixture.values) {
        final response = await _source(forced: fixture).analyze(_request(''));

        expect(response.statusCode, 200, reason: fixture.name);
        expect(
          const AnalysisResponseValidator().validate(response.body).isOk,
          isTrue,
          reason: fixture.name,
        );
      }
    });

    test('waits out its simulated latency', () async {
      final source = MockAnalysisRemoteDataSource(
        loadAsset: _loadFromDisk,
        latency: const Duration(milliseconds: 50),
      );

      final watch = Stopwatch()..start();
      await source.analyze(_request('فاتورة'));
      watch.stop();

      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(40));
    });
  });
}
