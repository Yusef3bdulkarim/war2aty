import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/analysis/data/validators/analysis_response_validator.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_date.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_status.dart';
import 'package:war2aty/features/analysis/domain/entities/confidence_band.dart';
import 'package:war2aty/features/analysis/domain/entities/document_analysis.dart';
import 'package:war2aty/features/analysis/domain/entities/document_kind.dart';

const _validator = AnalysisResponseValidator();

/// A body with every required field and nothing optional.
Map<String, dynamic> _minimal() => {
  'schema_version': '1.0',
  'session_id': 'session-1',
  'status': 'success',
  'document_type': {
    'type': 'invoice',
    'title': 'فاتورة كهرباء',
    'confidence': 'high',
  },
  'summary': {'short': 'قصير.', 'detailed': 'تفصيلي.'},
};

Map<String, dynamic> _withDate(Map<String, dynamic> date) =>
    _minimal()..['dates'] = [date];

DocumentAnalysis _expectOk(Result<DocumentAnalysis, AppFailure> result) {
  expect(result.isOk, isTrue, reason: 'expected Ok, got $result');
  return result.valueOrNull!;
}

void _expectInvalid(Result<DocumentAnalysis, AppFailure> result) {
  expect(result.failureOrNull, isA<InvalidAnalysisResponseFailure>());
}

void main() {
  group('valid payloads', () {
    test('maps a minimal body straight through to the domain', () {
      final analysis = _expectOk(_validator.validate(_minimal()));

      expect(analysis.sessionId, 'session-1');
      expect(analysis.status, AnalysisStatus.success);
      expect(analysis.kind, DocumentKind.invoice);
      expect(analysis.dates, isEmpty);
      expect(analysis.amounts, isEmpty);
    });

    test('accepts a real decoded JSON string', () {
      final decoded = jsonDecode(jsonEncode(_minimal()));

      expect(_validator.validate(decoded).isOk, isTrue);
    });

    test('passes an unsupported status through as a valid response', () {
      final body = _minimal()..['status'] = 'unsupported';

      // Not the validator's job to turn this into a failure — §31 rule 6.
      final analysis = _expectOk(_validator.validate(body));
      expect(analysis.status, AnalysisStatus.unsupported);
    });
  });

  group('schema version', () {
    test('accepts the supported version', () {
      expect(kSupportedAnalysisSchemaVersions, contains('1.0'));
      expect(_validator.validate(_minimal()).isOk, isTrue);
    });

    test('rejects an unknown version without parsing the body', () {
      for (final version in ['2.0', '0.9', '1', '']) {
        final body = _minimal()..['schema_version'] = version;

        _expectInvalid(_validator.validate(body));
      }
    });

    test('rejects a missing or non-string version', () {
      _expectInvalid(_validator.validate(_minimal()..remove('schema_version')));
      _expectInvalid(_validator.validate(_minimal()..['schema_version'] = 1.0));
      _expectInvalid(
        _validator.validate(_minimal()..['schema_version'] = null),
      );
    });
  });

  group('safe parse', () {
    test('does not crash on a missing required field', () {
      const required = ['session_id', 'status', 'document_type', 'summary'];

      for (final field in required) {
        final body = _minimal()..remove(field);

        _expectInvalid(_validator.validate(body));
      }
    });

    test('does not crash on a missing nested required field', () {
      final noTitle = _minimal();
      (noTitle['document_type']! as Map<String, dynamic>).remove('title');
      _expectInvalid(_validator.validate(noTitle));

      final noDetailed = _minimal();
      (noDetailed['summary']! as Map<String, dynamic>).remove('detailed');
      _expectInvalid(_validator.validate(noDetailed));
    });

    test('does not crash on a field of the wrong type', () {
      _expectInvalid(_validator.validate(_minimal()..['session_id'] = 42));
      _expectInvalid(_validator.validate(_minimal()..['summary'] = 'نص'));
      _expectInvalid(_validator.validate(_minimal()..['dates'] = 'مش قائمة'));
      _expectInvalid(
        _validator.validate(_minimal()..['missing_fields'] = [1, 2]),
      );
    });

    test('does not crash on a malformed date or role', () {
      _expectInvalid(
        _validator.validate(
          _withDate({
            'label': 'موعد',
            'date': '15/04/2024',
            'time': null,
            'role': 'deadline',
            'is_reminder_worthy': true,
            'confidence': 'high',
          }),
        ),
      );

      _expectInvalid(
        _validator.validate(
          _withDate({
            'label': 'موعد',
            'date': '2024-04-15',
            'time': null,
            'role': 'not-a-role',
            'is_reminder_worthy': true,
            'confidence': 'high',
          }),
        ),
      );
    });

    test('does not crash on a body that is not a JSON object', () {
      _expectInvalid(_validator.validate(null));
      _expectInvalid(_validator.validate('<html>502 Bad Gateway</html>'));
      _expectInvalid(_validator.validate(<Object>[]));
      _expectInvalid(_validator.validate(42));
    });

    test('does not crash on an empty object', () {
      _expectInvalid(_validator.validate(<String, dynamic>{}));
    });
  });

  group('confidence bands', () {
    test('carries each band through to the domain', () {
      const bands = {
        'high': ConfidenceBand.high,
        'medium': ConfidenceBand.medium,
        'low': ConfidenceBand.low,
      };

      for (final entry in bands.entries) {
        final body = _minimal();
        (body['document_type']! as Map<String, dynamic>)['confidence'] =
            entry.key;

        expect(
          _expectOk(_validator.validate(body)).kindConfidence,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('degrades an unreadable band to low instead of failing', () {
      final body = _minimal();
      (body['document_type']! as Map<String, dynamic>)['confidence'] = 'sure';

      final analysis = _expectOk(_validator.validate(body));
      expect(analysis.kindConfidence, ConfidenceBand.low);
      expect(analysis.hasUncertainFields, isTrue);
    });

    test('keeps a reminder-worthy date usable end to end', () {
      final analysis = _expectOk(
        _validator.validate(
          _withDate({
            'label': 'آخر موعد للسداد',
            'date': '2024-04-15',
            'time': '14:30',
            'role': 'deadline',
            'is_reminder_worthy': true,
            'confidence': 'medium',
          }),
        ),
      );

      final date = analysis.reminderCandidates.single;
      expect(date.role, DateRole.deadline);
      expect(date.date, DateTime(2024, 4, 15));
      expect(date.time, const AnalysisTime(hour: 14, minute: 30));
      expect(date.confidence, ConfidenceBand.medium);
    });
  });
}
