import 'candidates_dto.dart';

final class AnalysisRequestDto {
  const AnalysisRequestDto({
    required this.schemaVersion,
    required this.sessionId,
    required this.installationId,
    required this.appVersion,
    required this.ocrText,
    required this.detectedLanguages,
    required this.candidates,
  });

  factory AnalysisRequestDto.fromJson(Map<String, dynamic> json) {
    return AnalysisRequestDto(
      schemaVersion: json['schema_version'] as String,
      sessionId: json['session_id'] as String,
      installationId: json['installation_id'] as String,
      appVersion: json['app_version'] as String,
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
  final String ocrText;
  final List<String> detectedLanguages;
  final CandidatesDto candidates;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'session_id': sessionId,
    'installation_id': installationId,
    'app_version': appVersion,
    'ocr_text': ocrText,
    'detected_languages': detectedLanguages,
    'candidates': candidates.toJson(),
  };
}
