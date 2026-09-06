import 'candidates_dto.dart';

/// The text-shape (§29 v2) analyze-document request. The only shape this app
/// sends today — the image-intake shape has no DTO yet (F13-T14).
final class AnalysisRequestDto {
  const AnalysisRequestDto({
    required this.schemaVersion,
    required this.sessionId,
    required this.installationId,
    required this.appVersion,
    required this.ocrText,
    required this.detectedLanguages,
    required this.candidates,
    this.inputType = 'text',
  });

  factory AnalysisRequestDto.fromJson(Map<String, dynamic> json) {
    return AnalysisRequestDto(
      schemaVersion: json['schema_version'] as String,
      sessionId: json['session_id'] as String,
      installationId: json['installation_id'] as String,
      appVersion: json['app_version'] as String,
      inputType: json['input_type'] as String? ?? 'text',
      ocrText: json['ocr_text'] as String,
      detectedLanguages: (json['detected_languages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      candidates: CandidatesDto.fromJson(
        json['candidates'] as Map<String, dynamic>,
      ),
    );
  }

  final String schemaVersion;
  final String sessionId;
  final String installationId;
  final String appVersion;

  /// Discriminant (§29 v2). Always `'text'` until F13-T14 adds an
  /// image-intake DTO.
  final String inputType;
  final String ocrText;
  final List<String> detectedLanguages;
  final CandidatesDto candidates;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'session_id': sessionId,
    'installation_id': installationId,
    'app_version': appVersion,
    'input_type': inputType,
    'ocr_text': ocrText,
    'detected_languages': detectedLanguages,
    'candidates': candidates.toJson(),
  };
}
