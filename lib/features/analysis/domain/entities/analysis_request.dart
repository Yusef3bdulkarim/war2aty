import '../../../../core/utils/list_equality.dart';
import '../../../ocr/domain/entities/extraction_result.dart';

/// Everything that leaves the phone for one analysis — and nothing else.
///
/// The privacy rule is structural, not a convention: this type has no field
/// for the image, its path, a thumbnail, EXIF or GPS, so there is nothing for
/// the request builder to leak. Only OCR text and rule-based candidates travel
/// (project rule §7).
///
/// `installation_id` and `app_version` are deliberately absent too — they are
/// technical identity, filled in by the data layer rather than passed down
/// from the UI.
///
/// Pure Dart, no Flutter import.
final class AnalysisRequest {
  const AnalysisRequest({
    required this.sessionId,
    required this.extraction,
    this.detectedLanguages = const [],
  });

  /// `AnalysisSession.id` — scopes this run. An identifier, not content.
  final String sessionId;

  /// The local OCR + extraction output this analysis is based on.
  final ExtractionResult extraction;

  /// BCP-47 tags the OCR engine reported, e.g. `['ar', 'en']`. Empty when the
  /// engine could not tell.
  final List<String> detectedLanguages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisRequest &&
          other.sessionId == sessionId &&
          other.extraction == extraction &&
          listEquals(other.detectedLanguages, detectedLanguages);

  @override
  int get hashCode =>
      Object.hash(sessionId, extraction, Object.hashAll(detectedLanguages));

  // Contents omitted on purpose — never log document text (privacy §7).
  @override
  String toString() => 'AnalysisRequest($sessionId)';
}
