import '../../../../core/error/app_failure.dart';
import '../../../ocr/domain/entities/extraction_result.dart';

/// States for the OCR review screen (F14) — the online route's stop between
/// Azure OCR and Groq analysis.
sealed class OcrReviewState {
  const OcrReviewState();
}

/// Azure OCR is running on the server.
final class OcrReviewLoading extends OcrReviewState {
  const OcrReviewLoading();
}

/// OCR succeeded — the user is reviewing/editing the result before it goes
/// on to analysis.
final class OcrReviewReady extends OcrReviewState {
  const OcrReviewReady({
    required this.originalOcrText,
    required this.reviewedOcrText,
    required this.serverCandidates,
    required this.detectedLanguages,
    required this.imagePath,
  });

  /// The text Azure returned, untouched. Kept so [isEdited] can tell whether
  /// the user changed anything — never shown or logged on its own (§7).
  final String originalOcrText;

  /// User-editable text, starting as a copy of [originalOcrText] and updated
  /// via `OcrReviewCubit.updateOcrText`. This is what Groq ultimately sees.
  final String reviewedOcrText;

  /// Candidates extracted server-side (Azure + extractors). Shown as review
  /// hints only — when the user taps analyze, fresh candidates are
  /// re-extracted from [reviewedOcrText] client-side (`buildReviewedResult`),
  /// so Groq never receives a candidate that does not match the approved
  /// text.
  final ExtractionResult serverCandidates;

  /// Languages Azure detected, carried through to the analysis request once
  /// the user approves.
  final List<String> detectedLanguages;

  /// Path to the perspective-corrected temp image, so the user can view it
  /// alongside the text. Stays on disk for the whole review (F14 image
  /// lifecycle) — `null` only if it was already cleaned up.
  final String? imagePath;

  /// Whether the user has changed the text since OCR completed.
  bool get isEdited => originalOcrText != reviewedOcrText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrReviewReady &&
          other.originalOcrText == originalOcrText &&
          other.reviewedOcrText == reviewedOcrText &&
          other.serverCandidates == serverCandidates &&
          _listEquals(other.detectedLanguages, detectedLanguages) &&
          other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(
    originalOcrText,
    reviewedOcrText,
    serverCandidates,
    Object.hashAll(detectedLanguages),
    imagePath,
  );
}

/// OCR succeeded but the text is too short/empty to review — distinct from
/// [OcrReviewFailed] because nothing went wrong technically, the paper just
/// did not yield usable text (§ locked correction #7).
final class OcrReviewPoorQuality extends OcrReviewState {
  const OcrReviewPoorQuality({this.imagePath});

  final String? imagePath;

  @override
  bool operator ==(Object other) =>
      other is OcrReviewPoorQuality && other.imagePath == imagePath;

  @override
  int get hashCode => imagePath.hashCode;
}

/// The OCR request itself failed — network, server error, declined consent.
final class OcrReviewFailed extends OcrReviewState {
  const OcrReviewFailed(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is OcrReviewFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
