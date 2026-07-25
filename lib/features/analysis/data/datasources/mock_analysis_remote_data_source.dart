import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/analysis_request_dto.dart';
import 'analysis_fixture.dart';
import 'analysis_remote_data_source.dart';

/// Loads an asset as a string. Injected so tests don't need a Flutter binding.
typedef AssetStringLoader = Future<String> Function(String key);

/// Serves the bundled fixtures instead of calling the Edge Function.
///
/// Lets the result screen (F07) be built and demoed against every response
/// shape — success, partial, unsupported — before Groq exists. Registered in
/// place of the real datasource by DI; the repository above it cannot tell the
/// difference.
final class MockAnalysisRemoteDataSource implements AnalysisRemoteDataSource {
  MockAnalysisRemoteDataSource({
    AssetStringLoader? loadAsset,
    this.forcedFixture,
    this.latency = const Duration(milliseconds: 900),
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  final AssetStringLoader _loadAsset;

  /// Always answer with this fixture, whatever the request says. Handy for
  /// demoing one screen state; leave null to pick from the OCR text.
  final AnalysisFixture? forcedFixture;

  /// Stand-in for network + model time, so the loading state is real enough
  /// to design against.
  final Duration latency;

  @override
  Future<AnalysisApiResponse> analyze(AnalysisRequestDto request) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final fixture = forcedFixture ?? fixtureForText(request.ocrText);
    final json = await _loadAsset(fixture.assetPath);

    return AnalysisApiResponse(statusCode: 200, body: jsonDecode(json));
  }
}

/// Picks the fixture whose document type the OCR text looks most like.
///
/// A crude keyword match, and deliberately so — it exists to make the mock
/// feel alive while F07 is built, and is deleted with the mock. Real
/// classification is the model's job, never the client's.
AnalysisFixture fixtureForText(String ocrText) {
  for (final entry in _keywords.entries) {
    if (entry.value.any(ocrText.contains)) return entry.key;
  }
  return AnalysisFixture.invoice;
}

const _keywords = <AnalysisFixture, List<String>>{
  AnalysisFixture.appointment: ['موعد', 'كشف', 'عيادة', 'مستشفى', 'حجز'],
  AnalysisFixture.government: ['ضرائب', 'مصلحة', 'إخطار', 'إقرار', 'مأمورية'],
  AnalysisFixture.exam: ['نتيجة', 'ثانوية', 'الجلوس', 'درجات', 'امتحان'],
  AnalysisFixture.invoice: ['فاتورة', 'كهرباء', 'مياه', 'غاز', 'استهلاك'],
};
