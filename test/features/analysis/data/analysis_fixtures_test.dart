import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/features/analysis/data/datasources/analysis_fixture.dart';
import 'package:war2aty/features/analysis/data/validators/analysis_response_validator.dart';

const _validator = AnalysisResponseValidator();

/// Reads the fixture off disk rather than through `rootBundle`, so the test
/// exercises the file that actually ships.
DocumentAnalysis _load(AnalysisFixture fixture) {
  final file = File(fixture.assetPath);
  expect(file.existsSync(), isTrue, reason: 'missing ${fixture.assetPath}');

  final result = _validator.validate(jsonDecode(file.readAsStringSync()));
  expect(
    result.isOk,
    isTrue,
    reason: '${fixture.name} failed validation: ${result.failureOrNull}',
  );
  return result.valueOrNull!;
}

void main() {
  group('every fixture', () {
    test('parses through the real validator', () {
      for (final fixture in AnalysisFixture.values) {
        final analysis = _load(fixture);

        expect(analysis.sessionId, isNotEmpty, reason: fixture.name);
        expect(analysis.title, isNotEmpty, reason: fixture.name);
        expect(analysis.summary.short, isNotEmpty, reason: fixture.name);
        expect(analysis.summary.detailed, isNotEmpty, reason: fixture.name);
      }
    });

    test('keeps the short summary within the schema limit', () {
      for (final fixture in AnalysisFixture.values) {
        expect(
          _load(fixture).summary.short.length,
          lessThanOrEqualTo(200),
          reason: fixture.name,
        );
      }
    });

    test('has a unique session id', () {
      final ids = {
        for (final fixture in AnalysisFixture.values) _load(fixture).sessionId,
      };

      expect(ids, hasLength(AnalysisFixture.values.length));
    });

    test('is declared as a bundled asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('assets/fixtures/analysis/'));
    });

    test('covers the six cases F05-T08 calls for', () {
      expect(AnalysisFixture.values, hasLength(6));
      expect(AnalysisFixture.values.map((f) => f.name), [
        'invoice',
        'appointment',
        'government',
        'exam',
        'partial',
        'unsupported',
      ]);
    });
  });

  group('invoice', () {
    test('is a full success with a reminder-worthy deadline', () {
      final analysis = _load(AnalysisFixture.invoice);

      expect(analysis.status, AnalysisStatus.success);
      expect(analysis.kind, DocumentKind.invoice);
      expect(analysis.isPartial, isFalse);
      expect(analysis.missingFields, isEmpty);

      final deadline = analysis.reminderCandidates.single;
      expect(deadline.role, DateRole.deadline);
      expect(deadline.date, DateTime(2024, 4, 15));
      expect(deadline.confidence, ConfidenceBand.high);
    });

    test('carries the amounts the result screen renders', () {
      final analysis = _load(AnalysisFixture.invoice);

      expect(analysis.amounts, hasLength(3));
      expect(analysis.amounts.first.value, 850.5);
      expect(analysis.amounts.first.currency, 'EGP');
      expect(analysis.actions, isNotEmpty);
      expect(analysis.instructions, isNotEmpty);
    });

    test('covers the billing period roles', () {
      final roles = _load(AnalysisFixture.invoice).dates.map((d) => d.role);

      expect(roles, containsAll([DateRole.periodStart, DateRole.periodEnd]));
    });
  });

  group('appointment', () {
    test('carries a date with a time', () {
      final analysis = _load(AnalysisFixture.appointment);

      expect(analysis.kind, DocumentKind.appointment);

      final visit = analysis.reminderCandidates.single;
      expect(visit.role, DateRole.appointment);
      expect(visit.time, const AnalysisTime(hour: 10, minute: 30));
    });

    test('carries a medical warning and required documents', () {
      final analysis = _load(AnalysisFixture.appointment);

      expect(analysis.warnings.single.kind, WarningKind.medical);
      expect(analysis.requiredDocuments, isNotEmpty);
    });
  });

  group('government', () {
    test('leads with required documents and no amounts', () {
      final analysis = _load(AnalysisFixture.government);

      expect(analysis.kind, DocumentKind.government);
      expect(analysis.amounts, isEmpty);
      expect(analysis.requiredDocuments, hasLength(4));
      expect(
        analysis.warnings.map((w) => w.kind),
        containsAll([WarningKind.government, WarningKind.legal]),
      );
    });
  });

  group('exam', () {
    test('marks a derived percentage as inferred', () {
      final analysis = _load(AnalysisFixture.exam);

      expect(analysis.kind, DocumentKind.exam);
      expect(
        analysis.keyInformation.any((i) => i.source == InfoSource.inferred),
        isTrue,
      );
      expect(analysis.reminderCandidates.single.role, DateRole.event);
    });
  });

  group('partial', () {
    test('reports missing fields and uncertain values', () {
      final analysis = _load(AnalysisFixture.partial);

      expect(analysis.status, AnalysisStatus.partial);
      expect(analysis.isPartial, isTrue);
      expect(analysis.missingFields, isNotEmpty);
      expect(analysis.hasUncertainFields, isTrue);
      expect(analysis.amounts.single.confidence, ConfidenceBand.low);
    });
  });

  group('unsupported', () {
    test('is empty apart from the summary', () {
      final analysis = _load(AnalysisFixture.unsupported);

      expect(analysis.status, AnalysisStatus.unsupported);
      expect(analysis.kind, DocumentKind.other);
      expect(analysis.keyInformation, isEmpty);
      expect(analysis.dates, isEmpty);
      expect(analysis.amounts, isEmpty);
      expect(analysis.actions, isEmpty);
      expect(analysis.warnings, isEmpty);
      expect(analysis.summary.detailed, isNotEmpty);
    });
  });
}
