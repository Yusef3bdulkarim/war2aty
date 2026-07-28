/// Classified failure type returned across every layer via `Result<T, AppFailure>`.
///
/// The taxonomy mirrors master plan §47: three sealed categories
/// ([LocalFailure], [NetworkFailure], [BusinessFailure]) with concrete leaves.
/// Presentation maps each leaf to Arabic copy — failures deliberately carry no
/// server-provided message, and never carry document content (privacy §7).
///
/// Pure Dart, no Flutter import: the domain layer depends on this type.
sealed class AppFailure {
  const AppFailure();

  // Marker leaves are equal by type; data-carrying leaves override to also
  // compare their fields. Failures live inside Cubit states, so value
  // equality keeps rebuilds correct.
  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

// ---------------------------------------------------------------------------
// Local failures — on-device: camera, image, OCR, storage, notifications, TTS.
// ---------------------------------------------------------------------------
sealed class LocalFailure extends AppFailure {
  const LocalFailure();
}

final class CameraPermissionFailure extends LocalFailure {
  const CameraPermissionFailure();
}

final class GalleryAccessFailure extends LocalFailure {
  const GalleryAccessFailure();
}

final class ImageQualityFailure extends LocalFailure {
  const ImageQualityFailure();
}

final class ImageProcessingFailure extends LocalFailure {
  const ImageProcessingFailure();
}

final class OcrInitializationFailure extends LocalFailure {
  const OcrInitializationFailure();
}

final class OcrFailure extends LocalFailure {
  const OcrFailure();
}

final class NoTextDetectedFailure extends LocalFailure {
  const NoTextDetectedFailure();
}

final class LocalDatabaseFailure extends LocalFailure {
  const LocalDatabaseFailure();
}

/// A launch step crashed or never finished.
///
/// Distinct from the failures a step *returns*: this is the orchestrator
/// catching something a step was never supposed to do — an unregistered
/// dependency, a client that failed to initialize. Without its own code these
/// would be logged as whatever leaf happened to be nearest, sending the next
/// person debugging a dead splash screen down the wrong path.
final class LaunchFailure extends LocalFailure {
  const LaunchFailure();
}

final class FileEncryptionFailure extends LocalFailure {
  const FileEncryptionFailure();
}

final class FileStorageFailure extends LocalFailure {
  const FileStorageFailure();
}

final class NotificationPermissionFailure extends LocalFailure {
  const NotificationPermissionFailure();
}

final class NotificationSchedulingFailure extends LocalFailure {
  const NotificationSchedulingFailure();
}

final class TtsFailure extends LocalFailure {
  const TtsFailure();
}

// ---------------------------------------------------------------------------
// Network failures — talking to the Supabase Edge Function / analysis service.
// ---------------------------------------------------------------------------
sealed class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

final class NoInternetFailure extends NetworkFailure {
  const NoInternetFailure();
}

final class RequestTimeoutFailure extends NetworkFailure {
  const RequestTimeoutFailure();
}

final class UnauthorizedFailure extends NetworkFailure {
  const UnauthorizedFailure();
}

/// Daily analysis limit (3/day, Africa/Cairo) reached.
///
/// Carries when the quota resets so the UI can tell the user when to retry.
final class DailyLimitReachedFailure extends NetworkFailure {
  const DailyLimitReachedFailure(this.resetAtCairo);

  final DateTime resetAtCairo;

  @override
  bool operator ==(Object other) =>
      other is DailyLimitReachedFailure && other.resetAtCairo == resetAtCairo;

  @override
  int get hashCode => resetAtCairo.hashCode;
}

final class AnalysisDisabledFailure extends NetworkFailure {
  const AnalysisDisabledFailure();
}

final class UnsupportedAppVersionFailure extends NetworkFailure {
  const UnsupportedAppVersionFailure();
}

final class InvalidRequestFailure extends NetworkFailure {
  const InvalidRequestFailure();
}

final class AnalysisServiceFailure extends NetworkFailure {
  const AnalysisServiceFailure();
}

final class InvalidAnalysisResponseFailure extends NetworkFailure {
  const InvalidAnalysisResponseFailure();
}

final class AiProviderRateLimitFailure extends NetworkFailure {
  const AiProviderRateLimitFailure();
}

// ---------------------------------------------------------------------------
// Business failures — the request/response was valid but the outcome isn't.
// ---------------------------------------------------------------------------
sealed class BusinessFailure extends AppFailure {
  const BusinessFailure();
}

final class UnsupportedDocumentFailure extends BusinessFailure {
  const UnsupportedDocumentFailure();
}

/// The document was analysed but some fields could not be read with confidence.
///
/// Carries the names of the fields that are missing/uncertain.
final class PartialAnalysisFailure extends BusinessFailure {
  PartialAnalysisFailure(List<String> missingFields)
    : missingFields = List.unmodifiable(missingFields);

  final List<String> missingFields;

  @override
  bool operator ==(Object other) =>
      other is PartialAnalysisFailure &&
      _listEquals(other.missingFields, missingFields);

  @override
  int get hashCode => Object.hashAll(missingFields);
}

final class AmbiguousDateFailure extends BusinessFailure {
  const AmbiguousDateFailure();
}

final class MissingReminderTimeFailure extends BusinessFailure {
  const MissingReminderTimeFailure();
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
