import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/tts_error_code.dart';
import 'package:war2aty/core/error/app_failure.dart';

/// Category-level exhaustive switch — compile-enforced over the three groups.
String _categoryOf(AppFailure failure) => switch (failure) {
  LocalFailure() => 'local',
  NetworkFailure() => 'network',
  BusinessFailure() => 'business',
};

/// Leaf-level exhaustive switch over ALL 37 leaves with no `default`.
///
/// This is the exhaustiveness guard: adding a new [AppFailure] leaf without
/// handling it here fails to compile, so the taxonomy can never silently grow.
String _describe(AppFailure failure) => switch (failure) {
  // Local
  CameraPermissionFailure() => 'camera-permission',
  GalleryAccessFailure() => 'gallery-access',
  ImageProcessingFailure() => 'image-processing',
  OcrInitializationFailure() => 'ocr-init',
  OcrFailure() => 'ocr',
  NoTextDetectedFailure() => 'no-text',
  LocalDatabaseFailure() => 'local-db',
  LaunchFailure() => 'launch',
  FileEncryptionFailure() => 'file-encryption',
  FileStorageFailure() => 'file-storage',
  NotificationPermissionFailure() => 'notification-permission',
  NotificationSchedulingFailure() => 'notification-scheduling',
  TtsFailure() => 'tts',
  TtsEngineUnavailableFailure() => 'tts-engine-unavailable',
  NoArabicVoiceFailure() => 'tts-no-arabic-voice',
  ExternalLinkFailure() => 'external-link',
  AudioPlaybackFailure() => 'audio-playback',
  AudioEncodingFailure() => 'audio-encoding',
  // Network
  NoInternetFailure() => 'no-internet',
  RequestTimeoutFailure() => 'timeout',
  UnauthorizedFailure() => 'unauthorized',
  DailyLimitReachedFailure() => 'daily-limit',
  GlobalCapacityReachedFailure() => 'global-capacity',
  AnalysisDisabledFailure() => 'analysis-disabled',
  UnsupportedAppVersionFailure() => 'unsupported-app-version',
  InvalidRequestFailure() => 'invalid-request',
  AnalysisServiceFailure() => 'analysis-service',
  InvalidAnalysisResponseFailure() => 'invalid-response',
  AiProviderRateLimitFailure() => 'ai-provider-rate-limit',
  OnlineOcrUnavailableFailure() => 'online-ocr-unavailable',
  VoiceServiceFailure() => 'voice-service',
  VoiceStreamInterruptedFailure() => 'voice-stream-interrupted',
  // Business
  UnsupportedDocumentFailure() => 'unsupported-document',
  PartialAnalysisFailure() => 'partial-analysis',
  AmbiguousDateFailure() => 'ambiguous-date',
  MissingReminderTimeFailure() => 'missing-reminder-time',
  VoiceReadNotVerbatimFailure() => 'voice-read-not-verbatim',
};

void main() {
  final localLeaves = <AppFailure>[
    const CameraPermissionFailure(),
    const GalleryAccessFailure(),
    const ImageProcessingFailure(),
    const OcrInitializationFailure(),
    const OcrFailure(),
    const NoTextDetectedFailure(),
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
  ];
  final networkLeaves = <AppFailure>[
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
    const OnlineOcrUnavailableFailure(),
    const VoiceServiceFailure(),
    const VoiceStreamInterruptedFailure(Duration(seconds: 1)),
  ];
  final businessLeaves = <AppFailure>[
    const UnsupportedDocumentFailure(),
    PartialAnalysisFailure(['amount']),
    const AmbiguousDateFailure(),
    const MissingReminderTimeFailure(),
    const VoiceReadNotVerbatimFailure(0.4),
  ];

  group('taxonomy shape', () {
    test('has 18 local + 14 network + 5 business leaves', () {
      expect(localLeaves, hasLength(18));
      expect(networkLeaves, hasLength(14));
      expect(businessLeaves, hasLength(5));
    });
  });

  group('category-level exhaustiveness', () {
    test('every local leaf resolves to "local"', () {
      for (final f in localLeaves) {
        expect(_categoryOf(f), 'local');
      }
    });

    test('every network leaf resolves to "network"', () {
      for (final f in networkLeaves) {
        expect(_categoryOf(f), 'network');
      }
    });

    test('every business leaf resolves to "business"', () {
      for (final f in businessLeaves) {
        expect(_categoryOf(f), 'business');
      }
    });
  });

  group('leaf-level exhaustiveness', () {
    test('all 37 leaves describe to distinct labels', () {
      final all = [...localLeaves, ...networkLeaves, ...businessLeaves];
      final labels = all.map(_describe).toSet();
      expect(labels, hasLength(37));
    });
  });

  group('equality', () {
    test('marker leaves are equal by type', () {
      expect(const OcrFailure(), const OcrFailure());
      expect(const OcrFailure().hashCode, const OcrFailure().hashCode);
    });

    test('different marker leaves are not equal', () {
      expect(const OcrFailure(), isNot(equals(const NoInternetFailure())));
    });

    test('DailyLimitReachedFailure compares resetAtCairo', () {
      expect(
        DailyLimitReachedFailure(DateTime(2026, 7, 21)),
        DailyLimitReachedFailure(DateTime(2026, 7, 21)),
      );
      expect(
        DailyLimitReachedFailure(DateTime(2026, 7, 21)),
        isNot(equals(DailyLimitReachedFailure(DateTime(2026, 7, 22)))),
      );
    });

    test('PartialAnalysisFailure compares missingFields', () {
      expect(
        PartialAnalysisFailure(['amount', 'date']),
        PartialAnalysisFailure(['amount', 'date']),
      );
      expect(
        PartialAnalysisFailure(['amount']),
        isNot(equals(PartialAnalysisFailure(['date']))),
      );
    });
  });
}
