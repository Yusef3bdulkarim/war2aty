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

/// The device could not play the streamed audio at all (F37).
///
/// The `AudioTrack` sink refused to open, or the platform channel is not
/// there. Distinct from [AudioEncodingFailure] because the outcomes differ in
/// the way that matters: here the user heard **nothing**, so the read has to be
/// attempted again on the fallback tier. A failure to *save* what they already
/// heard is not worth re-reading a paper for.
final class AudioPlaybackFailure extends LocalFailure {
  const AudioPlaybackFailure();
}

/// The paper was spoken, but no `.m4a` came out of the encoder (F37).
///
/// Deliberately **not** treated as a failed read: the user has already heard
/// their paper. All that is lost is the offline replay, so the caller records
/// that this paper has no audio and moves on rather than spending another
/// 75 seconds and another Live session to produce a file nobody is waiting for.
final class AudioEncodingFailure extends LocalFailure {
  const AudioEncodingFailure();
}

/// Nothing on the device could open a link the app handed out (F27-T20).
///
/// A phone with no browser, or no mail app for a `mailto:`, is unusual but
/// real — and an invisible no-op on «شروط الاستخدام» would leave the user
/// tapping a row that does nothing, so the screen says so instead.
final class ExternalLinkFailure extends LocalFailure {
  const ExternalLinkFailure();
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

/// The reading voice could not be reached or refused the session (F37).
///
/// A token that could not be minted, a socket that would not open, a `1007`
/// close on the setup frame, or the service answering nothing usable. Not
/// [AnalysisServiceFailure]: that one names the analysis endpoint, and a voice
/// outage must not be reported as the paper having failed to be understood —
/// the explanation is already in hand, only the reading of it is missing.
///
/// Always falls back to device TTS rather than surfacing. It exists so the log
/// line distinguishes "the voice service is down" from "this phone cannot
/// speak".
final class VoiceServiceFailure extends NetworkFailure {
  const VoiceServiceFailure();
}

/// The voice stream stopped part-way through the paper (F37).
///
/// [heard] is how much of the reading actually reached the user before the
/// socket died, and it is the whole reason this is its own leaf: the Live API
/// cannot replay a partial turn, so reconnecting restarts from word one. Under
/// a couple of seconds that is the right thing to do; any further in, the user
/// would hear the beginning of their paper twice, so the read continues on
/// device TTS instead.
final class VoiceStreamInterruptedFailure extends NetworkFailure {
  const VoiceStreamInterruptedFailure(this.heard);

  final Duration heard;

  @override
  bool operator ==(Object other) =>
      other is VoiceStreamInterruptedFailure && other.heard == heard;

  @override
  int get hashCode => heard.hashCode;
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

/// The voice did not read the explanation as written (F37).
///
/// Live is a chat model used as a reader, so the risk it carries is not a bad
/// connection but a *reworded* paper — and a user who cannot read has no way to
/// notice that the date they were told is not the date on the page. The read is
/// checked against the service's own transcription of its own speech, so no
/// second speech-to-text is needed.
///
/// [wordErrorRate] is the measured divergence. It is carried so the retry
/// decision and the log line have a number, and it is the **only** thing about
/// the comparison that may be logged: the transcript and the source are both
/// document content (CLAUDE.md §7).
///
/// Only reported while the read can still be abandoned. Once the user has heard
/// most of the paper there is nothing to be gained by failing — the audio is
/// kept and marked unverified instead.
final class VoiceReadNotVerbatimFailure extends BusinessFailure {
  const VoiceReadNotVerbatimFailure(this.wordErrorRate);

  final double wordErrorRate;

  @override
  bool operator ==(Object other) =>
      other is VoiceReadNotVerbatimFailure &&
      other.wordErrorRate == wordErrorRate;

  @override
  int get hashCode => wordErrorRate.hashCode;
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
