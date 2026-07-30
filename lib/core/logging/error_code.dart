import '../error/app_failure.dart';

/// Maps an [AppFailure] to a stable, content-free log code.
///
/// Exhaustive over every leaf (no `default`): a new [AppFailure] added without
/// a code here fails to compile, so a failure can never be logged as an
/// unmapped or accidentally content-bearing string.
String errorCodeOf(AppFailure failure) => switch (failure) {
  // Local
  CameraPermissionFailure() => 'CAMERA_PERMISSION',
  GalleryAccessFailure() => 'GALLERY_ACCESS',
  ImageQualityFailure() => 'IMAGE_QUALITY',
  ImageProcessingFailure() => 'IMAGE_PROCESSING',
  OcrInitializationFailure() => 'OCR_INIT',
  OcrFailure() => 'OCR',
  NoTextDetectedFailure() => 'NO_TEXT_DETECTED',
  LocalDatabaseFailure() => 'LOCAL_DATABASE',
  LaunchFailure() => 'LAUNCH',
  FileEncryptionFailure() => 'FILE_ENCRYPTION',
  FileStorageFailure() => 'FILE_STORAGE',
  NotificationPermissionFailure() => 'NOTIFICATION_PERMISSION',
  NotificationSchedulingFailure() => 'NOTIFICATION_SCHEDULING',
  TtsFailure() => 'TTS',
  // Network
  NoInternetFailure() => 'NO_INTERNET',
  RequestTimeoutFailure() => 'REQUEST_TIMEOUT',
  UnauthorizedFailure() => 'UNAUTHORIZED',
  DailyLimitReachedFailure() => 'DAILY_LIMIT_REACHED',
  AnalysisDisabledFailure() => 'ANALYSIS_DISABLED',
  UnsupportedAppVersionFailure() => 'UNSUPPORTED_APP_VERSION',
  InvalidRequestFailure() => 'INVALID_REQUEST',
  AnalysisServiceFailure() => 'ANALYSIS_SERVICE',
  InvalidAnalysisResponseFailure() => 'INVALID_ANALYSIS_RESPONSE',
  AiProviderRateLimitFailure() => 'AI_PROVIDER_RATE_LIMIT',
  // Business
  UnsupportedDocumentFailure() => 'UNSUPPORTED_DOCUMENT',
  PartialAnalysisFailure() => 'PARTIAL_ANALYSIS',
  AmbiguousDateFailure() => 'AMBIGUOUS_DATE',
  MissingReminderTimeFailure() => 'MISSING_REMINDER_TIME',
};
