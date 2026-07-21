import 'runtime_config.dart';

/// Serialization model for [RuntimeConfig] — hand-written, no codegen.
///
/// Field names mirror the backend's `app_config` keys so the same shape works
/// for the cached copy and the future remote payload.
final class RuntimeConfigDto {
  const RuntimeConfigDto({
    required this.analysisEnabled,
    required this.dailyAnalysisLimit,
    required this.maxOcrCharacters,
    required this.analysisTimeoutSeconds,
    required this.schemaVersion,
    required this.minimumAppVersion,
    this.maintenanceMessage,
  });

  factory RuntimeConfigDto.fromJson(Map<String, dynamic> json) {
    return RuntimeConfigDto(
      analysisEnabled: json['analysis_enabled'] as bool,
      dailyAnalysisLimit: json['daily_limit'] as int,
      maxOcrCharacters: json['max_ocr_characters'] as int,
      analysisTimeoutSeconds: json['analysis_timeout_seconds'] as int,
      schemaVersion: json['schema_version'] as String,
      minimumAppVersion: json['minimum_app_version'] as String,
      maintenanceMessage: json['maintenance_message'] as String?,
    );
  }

  factory RuntimeConfigDto.fromEntity(RuntimeConfig config) {
    return RuntimeConfigDto(
      analysisEnabled: config.analysisEnabled,
      dailyAnalysisLimit: config.dailyAnalysisLimit,
      maxOcrCharacters: config.maxOcrCharacters,
      analysisTimeoutSeconds: config.analysisTimeout.inSeconds,
      schemaVersion: config.schemaVersion,
      minimumAppVersion: config.minimumAppVersion,
      maintenanceMessage: config.maintenanceMessage,
    );
  }

  final bool analysisEnabled;
  final int dailyAnalysisLimit;
  final int maxOcrCharacters;
  final int analysisTimeoutSeconds;
  final String schemaVersion;
  final String minimumAppVersion;
  final String? maintenanceMessage;

  Map<String, dynamic> toJson() => {
    'analysis_enabled': analysisEnabled,
    'daily_limit': dailyAnalysisLimit,
    'max_ocr_characters': maxOcrCharacters,
    'analysis_timeout_seconds': analysisTimeoutSeconds,
    'schema_version': schemaVersion,
    'minimum_app_version': minimumAppVersion,
    'maintenance_message': maintenanceMessage,
  };

  RuntimeConfig toEntity() => RuntimeConfig(
    analysisEnabled: analysisEnabled,
    dailyAnalysisLimit: dailyAnalysisLimit,
    maxOcrCharacters: maxOcrCharacters,
    analysisTimeout: Duration(seconds: analysisTimeoutSeconds),
    schemaVersion: schemaVersion,
    minimumAppVersion: minimumAppVersion,
    maintenanceMessage: maintenanceMessage,
  );
}
