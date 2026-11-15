final class ExplainImageDto {
  const ExplainImageDto({required this.data, required this.mimeType});

  final String data;
  final String mimeType;

  Map<String, dynamic> toJson() => {'data': data, 'mime_type': mimeType};
}

final class ExplainRequestDto {
  const ExplainRequestDto({
    required this.explainSchemaVersion,
    required this.sessionId,
    required this.installationId,
    required this.appVersion,
    required this.image,
  });

  final String explainSchemaVersion;
  final String sessionId;
  final String installationId;
  final String appVersion;
  final ExplainImageDto image;

  Map<String, dynamic> toJson() => {
    'explain_schema_version': explainSchemaVersion,
    'session_id': sessionId,
    'installation_id': installationId,
    'app_version': appVersion,
    'image': image.toJson(),
  };
}
