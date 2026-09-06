import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/analysis_image_request_dto.dart';
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

  /// No OCR text to keyword-match against an image, so this always answers
  /// with [forcedFixture] or the invoice fixture — enough to demo the online
  /// route's loading/result states before Azure/Google are wired (F13-T14).
  @override
  Future<AnalysisApiResponse> analyzeImage(
    AnalysisImageRequestDto request,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final fixture = forcedFixture ?? AnalysisFixture.invoice;
    final json = await _loadAsset(fixture.assetPath);

    return AnalysisApiResponse(statusCode: 200, body: jsonDecode(json));
  }

  /// Answers with a canned OCR response (F14) — enough to demo the OCR
  /// review screen before the `ocr-document` endpoint is deployed. Unlike
  /// [analyze]/[analyzeImage], there is no bundled asset per document type:
  /// the review screen only needs *some* text and candidates to look real.
  @override
  Future<AnalysisApiResponse> ocrImage(AnalysisImageRequestDto request) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    return const AnalysisApiResponse(statusCode: 200, body: _ocrFixtureBody);
  }
}

const Map<String, Object?> _ocrFixtureBody = {
  'schema_version': '2.0',
  'session_id': 'mock-ocr-session',
  'ocr_text':
      'شركة جنوب القاهرة لتوزيع الكهرباء\n'
      'فاتورة استهلاك شهر مارس 2024\n'
      'رقم الحساب: 12345678\n'
      'المبلغ المطلوب: 850.50 جنيه\n'
      'آخر موعد للسداد: 15/04/2024\n'
      'للاستفسار: 19980',
  'detected_languages': ['ar'],
  'candidates': {
    'dates': [
      {
        'raw_text': '15/04/2024',
        'normalized_date': '2024-04-15',
        'is_ambiguous': false,
      },
    ],
    'times': <Map<String, Object?>>[],
    'amounts': [
      {
        'raw_text': '850.50 جنيه',
        'value': 850.5,
        'currency': 'EGP',
        'is_ambiguous': false,
      },
    ],
    'phones': [
      {
        'raw_text': '19980',
        'normalized_number': '19980',
        'is_ambiguous': false,
      },
    ],
    'references': [
      {
        'raw_text': 'رقم الحساب: 12345678',
        'value': '12345678',
        'is_ambiguous': true,
      },
    ],
  },
};

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
