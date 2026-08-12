/// The image-shape (§29b v2) analyze-document request (F13-T09/T14).
///
/// Sibling to [AnalysisRequestDto], not a variant of it: `input_type` is
/// `const "image"` on the wire (no default, no mutable field) so this class
/// cannot accidentally be sent as the text shape.
final class AnalysisImageRequestDto {
  const AnalysisImageRequestDto({
    required this.schemaVersion,
    required this.sessionId,
    required this.installationId,
    required this.appVersion,
    required this.imageBase64,
    required this.mimeType,
  });

  final String schemaVersion;
  final String sessionId;
  final String installationId;
  final String appVersion;

  /// Base64-encoded image bytes (§29b `image.data`).
  final String imageBase64;

  /// `image/jpeg` or `image/png` only (§29b rule 3).
  final String mimeType;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'session_id': sessionId,
    'installation_id': installationId,
    'app_version': appVersion,
    'input_type': 'image',
    'image': {'data': imageBase64, 'mime_type': mimeType},
  };
}
