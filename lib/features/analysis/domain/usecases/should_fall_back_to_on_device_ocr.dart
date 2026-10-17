import '../../../../core/error/app_failure.dart';

/// Whether a failed online reading may be retried on the device instead
/// (F20 §1, layer 1).
///
/// Decided on the client, from the online reading's own failure only — an
/// analysis failure never reaches here. The allowlist is closed: exactly the
/// four failures an on-device reading can work around fall back, everything
/// else surfaces as it did before.
///
/// Exhaustive over every leaf, with no `default`: a new [AppFailure] fails to
/// compile until someone decides whether it falls back, so the allowlist can
/// never grow by accident.
bool shouldFallBackToOnDeviceOcr(AppFailure failure) => switch (failure) {
  // The online reader is busy, slow, down or switched off, or the phone is
  // offline — the page itself is fine (O3, O4, O5, O7, O10).
  AiProviderRateLimitFailure() ||
  RequestTimeoutFailure() ||
  OnlineOcrUnavailableFailure() ||
  NoInternetFailure() => true,

  // A deploy fault (bad key or model, O6; gateway 5xx, O11) or a broken
  // response contract (O13): a programmer must fix it, and hiding it behind a
  // weaker reading would keep it from being noticed.
  AnalysisServiceFailure() || InvalidAnalysisResponseFailure() => false,

  // The service refused the request itself (O9, O12): the same refusal would
  // meet the analysis that follows, so reading on the device gains nothing.
  UnauthorizedFailure() ||
  AnalysisDisabledFailure() ||
  UnsupportedAppVersionFailure() ||
  InvalidRequestFailure() => false,

  // The user declined sending anything (O8): their choice, not an outage.
  AnalysisConsentDeclinedFailure() => false,

  // Quota failures come from the analysis, never from a reading (a reading
  // takes no slot), so they cannot arrive here — and would not be helped.
  DailyLimitReachedFailure() || GlobalCapacityReachedFailure() => false,

  // Local failures. The only one an online reading can produce is
  // [ImageProcessingFailure] — the photo could not be read off disk — and
  // the on-device reader would fail on the same file. The rest belong to
  // other stages and are listed only to keep the switch exhaustive.
  CameraPermissionFailure() ||
  GalleryAccessFailure() ||
  ImageQualityFailure() ||
  ImageProcessingFailure() ||
  OcrInitializationFailure() ||
  OcrFailure() ||
  NoTextDetectedFailure() ||
  LocalDatabaseFailure() ||
  LaunchFailure() ||
  FileEncryptionFailure() ||
  FileStorageFailure() ||
  NotificationPermissionFailure() ||
  NotificationSchedulingFailure() ||
  TtsFailure() ||
  // Opening a policy page or a mail client (F27-T20) has nothing to do with
  // reading a paper; it is listed only to keep the switch exhaustive.
  ExternalLinkFailure() => false,

  // Business outcomes belong to a finished analysis, not to a reading.
  UnsupportedDocumentFailure() ||
  PartialAnalysisFailure() ||
  AmbiguousDateFailure() ||
  MissingReminderTimeFailure() => false,
};
