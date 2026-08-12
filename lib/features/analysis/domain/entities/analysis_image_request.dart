import '../../../capture/domain/entities/captured_photo.dart';

/// Everything needed to run one analysis over a captured image — the
/// online-only counterpart of [AnalysisRequest] (F13-T14).
///
/// Unlike [AnalysisRequest], this carries the photo itself: the online path's
/// entire reason to exist is sending it (F13 locked decisions — a privacy-model
/// change, the image now legitimately transits the Edge Function). [photo] is
/// expected to already be perspective-corrected (F13-T12), never the raw
/// sensor frame. Only the file path travels through the domain layer; bytes
/// are read at the data boundary (§29b).
///
/// `installation_id` and `app_version` are deliberately absent, same as
/// [AnalysisRequest] — technical identity filled in by the data layer.
///
/// Pure Dart, no Flutter import.
final class AnalysisImageRequest {
  const AnalysisImageRequest({required this.sessionId, required this.photo});

  /// `AnalysisSession.id` — scopes this run. An identifier, not content.
  final String sessionId;

  final CapturedPhoto photo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisImageRequest &&
          other.sessionId == sessionId &&
          other.photo == photo;

  @override
  int get hashCode => Object.hash(sessionId, photo);

  // Contents omitted on purpose — never log document content (privacy §7).
  @override
  String toString() => 'AnalysisImageRequest($sessionId)';
}
