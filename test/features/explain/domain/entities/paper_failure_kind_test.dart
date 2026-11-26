import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_error_code.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/explain/domain/entities/paper_failure_kind.dart';

PaperFailureKind _expectedKind(AppFailure failure) => switch (failure) {
  NoInternetFailure() => PaperFailureKind.offline,
  DailyLimitReachedFailure() => PaperFailureKind.limitReached,
  CameraPermissionFailure() ||
  GalleryAccessFailure() ||
  ImageProcessingFailure() ||
  LocalDatabaseFailure() ||
  LaunchFailure() ||
  FileEncryptionFailure() ||
  FileStorageFailure() ||
  NotificationPermissionFailure() ||
  NotificationSchedulingFailure() ||
  TtsFailure() ||
  TtsEngineUnavailableFailure() ||
  NoArabicVoiceFailure() ||
  ExternalLinkFailure() ||
  AudioPlaybackFailure() ||
  AudioEncodingFailure() ||
  RequestTimeoutFailure() ||
  UnauthorizedFailure() ||
  GlobalCapacityReachedFailure() ||
  AnalysisDisabledFailure() ||
  UnsupportedAppVersionFailure() ||
  InvalidRequestFailure() ||
  AnalysisServiceFailure() ||
  InvalidAnalysisResponseFailure() ||
  AiProviderRateLimitFailure() ||
  VoiceServiceFailure() ||
  VoiceStreamInterruptedFailure() ||
  UnsupportedDocumentFailure() ||
  PartialAnalysisFailure() ||
  AmbiguousDateFailure() ||
  MissingReminderTimeFailure() ||
  VoiceReadNotVerbatimFailure() => PaperFailureKind.serviceProblem,
};

void main() {
  final everyLeaf = <AppFailure>[
    const CameraPermissionFailure(),
    const GalleryAccessFailure(),
    const ImageProcessingFailure(),
    const LocalDatabaseFailure(),
    const LaunchFailure(),
    const FileEncryptionFailure(),
    const FileStorageFailure(),
    const NotificationPermissionFailure(),
    const NotificationSchedulingFailure(),
    const TtsFailure(),
    const TtsEngineUnavailableFailure(TtsErrorCode.service),
    const NoArabicVoiceFailure(),
    const ExternalLinkFailure(),
    const AudioPlaybackFailure(),
    const AudioEncodingFailure(),
    const NoInternetFailure(),
    const RequestTimeoutFailure(),
    const UnauthorizedFailure(),
    DailyLimitReachedFailure(DateTime(2026, 7, 21)),
    const GlobalCapacityReachedFailure(),
    const AnalysisDisabledFailure(),
    const UnsupportedAppVersionFailure(),
    const InvalidRequestFailure(),
    const AnalysisServiceFailure(),
    const InvalidAnalysisResponseFailure(),
    const AiProviderRateLimitFailure(),
    const VoiceServiceFailure(),
    const VoiceStreamInterruptedFailure(Duration(seconds: 1)),
    const UnsupportedDocumentFailure(),
    PartialAnalysisFailure(['amount']),
    const AmbiguousDateFailure(),
    const MissingReminderTimeFailure(),
    const VoiceReadNotVerbatimFailure(0.4),
  ];

  test('the table walks every AppFailure leaf', () {
    expect(everyLeaf, hasLength(33));
    expect(everyLeaf.map((f) => f.runtimeType).toSet(), hasLength(33));
  });

  test('every leaf maps to its expected kind', () {
    for (final failure in everyLeaf) {
      expect(
        PaperFailureKind.fromFailure(failure),
        _expectedKind(failure),
        reason: failure.runtimeType.toString(),
      );
    }
  });

  test('only no-internet reads as offline', () {
    final offline = everyLeaf.where(
      (f) => PaperFailureKind.fromFailure(f) == PaperFailureKind.offline,
    );
    expect(offline.map((f) => f.runtimeType), [NoInternetFailure]);
  });

  test('only the daily limit reads as limitReached', () {
    final limited = everyLeaf.where(
      (f) => PaperFailureKind.fromFailure(f) == PaperFailureKind.limitReached,
    );
    expect(limited.map((f) => f.runtimeType), [DailyLimitReachedFailure]);
  });

  test('every other leaf reads as serviceProblem', () {
    final rest = everyLeaf.where(
      (f) => PaperFailureKind.fromFailure(f) == PaperFailureKind.serviceProblem,
    );
    expect(rest, hasLength(31));
  });
}
