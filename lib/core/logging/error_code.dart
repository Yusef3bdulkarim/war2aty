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
  // The engine's own reason when it gave one (F30-T08) — `TTS` is kept for
  // the paths where nothing was reported, so the two stay distinguishable in
  // production rather than collapsing into one unexplained code.
  TtsFailure(:final code) => code?.logCode ?? 'TTS',
  TtsEngineUnavailableFailure(:final code) => code.logCode,
  NoArabicVoiceFailure() => 'TTS_NO_ARABIC_VOICE',
  ExternalLinkFailure() => 'EXTERNAL_LINK',
  AudioPlaybackFailure() => 'AUDIO_PLAYBACK',
  AudioEncodingFailure() => 'AUDIO_ENCODING',
  // Network
  NoInternetFailure() => 'NO_INTERNET',
  RequestTimeoutFailure() => 'REQUEST_TIMEOUT',
  UnauthorizedFailure() => 'UNAUTHORIZED',
  DailyLimitReachedFailure() => 'DAILY_LIMIT_REACHED',
  GlobalCapacityReachedFailure() => 'GLOBAL_CAPACITY_REACHED',
  AnalysisDisabledFailure() => 'ANALYSIS_DISABLED',
  UnsupportedAppVersionFailure() => 'UNSUPPORTED_APP_VERSION',
  InvalidRequestFailure() => 'INVALID_REQUEST',
  AnalysisServiceFailure() => 'ANALYSIS_SERVICE',
  InvalidAnalysisResponseFailure() => 'INVALID_ANALYSIS_RESPONSE',
  AiProviderRateLimitFailure() => 'AI_PROVIDER_RATE_LIMIT',
  OnlineOcrUnavailableFailure() => 'ONLINE_OCR_UNAVAILABLE',
  VoiceServiceFailure() => 'VOICE_SERVICE',
  VoiceStreamInterruptedFailure() => 'VOICE_STREAM_INTERRUPTED',
  // Business
  UnsupportedDocumentFailure() => 'UNSUPPORTED_DOCUMENT',
  PartialAnalysisFailure() => 'PARTIAL_ANALYSIS',
  AmbiguousDateFailure() => 'AMBIGUOUS_DATE',
  MissingReminderTimeFailure() => 'MISSING_REMINDER_TIME',
  // Stable on purpose, unlike [TtsFailure] above: the measured word error rate
  // belongs in a field beside this code, not inside it. Folding a float into
  // the code would mint an unbounded set of codes and make the one thing worth
  // counting — how often a read is refused — impossible to count.
  VoiceReadNotVerbatimFailure() => 'VOICE_READ_NOT_VERBATIM',
};
