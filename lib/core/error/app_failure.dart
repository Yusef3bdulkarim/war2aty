import '../audio/tts_error_code.dart';

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

/// The reader could not speak, and trying again might still work.
///
/// [code] is the engine's own reason, when the engine gave one (F30-T08):
/// `null` where it reported nothing at all — it threw, or it simply would
/// not take the utterance (F30-T09) — and otherwise a [TtsErrorCode] whose
/// [TtsErrorCode.isTransient] is true; the permanent ones are
/// [TtsEngineUnavailableFailure] instead.
/// Either way the user is told «حصلت مشكلة. جرّب تاني.»; the code exists so
/// the log line says which of them it was, which before T08 it could not
/// (F30 RC-2).
final class TtsFailure extends LocalFailure {
  const TtsFailure([this.code]);

  final TtsErrorCode? code;

  @override
  bool operator ==(Object other) => other is TtsFailure && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// The engine cannot do this reading at all, and retrying will not change
/// that (F30-T08).
///
/// Its own failure rather than a [TtsFailure], for the same reason
/// [NoArabicVoiceFailure] is: the two need different sentences. «جرّب تاني»
/// in front of a dead engine sends the user tapping at something that cannot
/// work — which is close to what F30 RC-2 describes from the other side,
/// where a *recoverable* error wore that same message and the owner had to
/// supply the retry by hand.
///
/// Reported only when the engine named a permanent condition itself. An
/// error it did not explain stays a [TtsFailure]: "we do not know" is not
/// grounds for telling someone their phone cannot read aloud.
final class TtsEngineUnavailableFailure extends LocalFailure {
  const TtsEngineUnavailableFailure(this.code);

  final TtsErrorCode code;

  @override
  bool operator ==(Object other) =>
      other is TtsEngineUnavailableFailure && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// The device has no Arabic reading voice installed (F30-T07).
///
/// Its own failure, rather than a [TtsFailure], because it is the one voice
/// problem the user can actually fix and the only one worth stopping a
/// reading over. Everything else about choosing a voice is best-effort: the
/// reading goes ahead on whatever the engine already had.
///
/// Until F30 this was silent. `StartReading` treated "no matching voice" as
/// nothing to report, so a phone whose engine ships no Arabic — Samsung TTS
/// in many regions — read an Arabic paper with an **English** voice, which
/// produces nothing audible for Arabic script and spells out the Latin
/// characters one at a time. That is exactly what the owner heard on a
/// Samsung phone, and why «الخلاصة» — one short, purely Arabic sentence —
/// appeared to do nothing at all while the longer modes made some sound
/// (F30 RC-1).
///
/// Reported only when the device listed voices and none of them was Arabic.
/// An engine that answered with no voices at all is still binding, and
/// claiming a missing voice on that basis would be wrong.
final class NoArabicVoiceFailure extends LocalFailure {
  const NoArabicVoiceFailure();
}

/// Nothing on the device could open a link the app handed out (F27-T20).
///
/// A phone with no browser, or no mail app for a `mailto:`, is unusual but
/// real — and an invisible no-op on «شروط الاستخدام» would leave the user
/// tapping a row that does nothing, so the screen says so instead.
final class ExternalLinkFailure extends LocalFailure {
  const ExternalLinkFailure();
}

/// The user has turned off «السماح بإرسال النص للتحليل» (F11-T02) — analysis
/// was never attempted, so this is not a network/business outcome, but a
/// local, user-controlled setting the request never got past.
final class AnalysisConsentDeclinedFailure extends LocalFailure {
  const AnalysisConsentDeclinedFailure();
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

/// The service-wide daily analysis capacity is spent (F13-T02).
///
/// Not the user's own quota — [DailyLimitReachedFailure] is that. This one is a
/// shared spend cap the user cannot influence and has not used up, so the two
/// must stay distinct: telling someone who has analysed nothing today that they
/// are out of analyses would be a lie they cannot act on.
///
/// Carries no reset instant: capacity also returns when an operator raises the
/// cap, so any promised time would be a guess.
final class GlobalCapacityReachedFailure extends NetworkFailure {
  const GlobalCapacityReachedFailure();
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

/// The online reading gave no usable text (`OCR_UNAVAILABLE`, F20-T18).
///
/// An upstream outage, a network failure on the server's side, an unusable
/// or blocked answer, or online reading switched off after the app chose the
/// online route. Not a deploy fault — that stays [AnalysisServiceFailure] —
/// so the page can still be read on the device instead (F20 matrix O5, O10).
final class OnlineOcrUnavailableFailure extends NetworkFailure {
  const OnlineOcrUnavailableFailure();
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
