import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';

/// Category-level exhaustive switch — compile-enforced over the three groups.
String _categoryOf(AppFailure failure) => switch (failure) {
  LocalFailure() => 'local',
  NetworkFailure() => 'network',
  BusinessFailure() => 'business',
};

/// Leaf-level exhaustive switch over ALL 27 leaves with no `default`.
///
/// This is the exhaustiveness guard: adding a new [AppFailure] leaf without
/// handling it here fails to compile, so the taxonomy can never silently grow.
String _describe(AppFailure failure) => switch (failure) {
  // Local
  CameraPermissionFailure() => 'camera-permission',
  GalleryAccessFailure() => 'gallery-access',
  ImageQualityFailure() => 'image-quality',
  ImageProcessingFailure() => 'image-processing',
  OcrInitializationFailure() => 'ocr-init',
  OcrFailure() => 'ocr',
  NoTextDetectedFailure() => 'no-text',
  LocalDatabaseFailure() => 'local-db',
  FileEncryptionFailure() => 'file-encryption',
  FileStorageFailure() => 'file-storage',
  NotificationPermissionFailure() => 'notification-permission',
  NotificationSchedulingFailure() => 'notification-scheduling',
  TtsFailure() => 'tts',
  // Network
  NoInternetFailure() => 'no-internet',
  RequestTimeoutFailure() => 'timeout',
  UnauthorizedFailure() => 'unauthorized',
  DailyLimitReachedFailure() => 'daily-limit',
  AnalysisDisabledFailure() => 'analysis-disabled',
  UnsupportedAppVersionFailure() => 'unsupported-app-version',
  InvalidRequestFailure() => 'invalid-request',
  AnalysisServiceFailure() => 'analysis-service',
  InvalidAnalysisResponseFailure() => 'invalid-response',
  GroqRateLimitFailure() => 'groq-rate-limit',
  // Business
  UnsupportedDocumentFailure() => 'unsupported-document',
  PartialAnalysisFailure() => 'partial-analysis',
  AmbiguousDateFailure() => 'ambiguous-date',
  MissingReminderTimeFailure() => 'missing-reminder-time',
};

void main() {
  final localLeaves = <AppFailure>[
    const CameraPermissionFailure(),
    const GalleryAccessFailure(),
    const ImageQualityFailure(),
    const ImageProcessingFailure(),
    const OcrInitializationFailure(),
    const OcrFailure(),
    const NoTextDetectedFailure(),
    const LocalDatabaseFailure(),
    const FileEncryptionFailure(),
    const FileStorageFailure(),
    const NotificationPermissionFailure(),
    const NotificationSchedulingFailure(),
    const TtsFailure(),
  ];
  final networkLeaves = <AppFailure>[
    const NoInternetFailure(),
    const RequestTimeoutFailure(),
    const UnauthorizedFailure(),
    DailyLimitReachedFailure(DateTime(2026, 7, 21)),
    const AnalysisDisabledFailure(),
    const UnsupportedAppVersionFailure(),
    const InvalidRequestFailure(),
    const AnalysisServiceFailure(),
    const InvalidAnalysisResponseFailure(),
    const GroqRateLimitFailure(),
  ];
  final businessLeaves = <AppFailure>[
    const UnsupportedDocumentFailure(),
    const PartialAnalysisFailure(['amount']),
    const AmbiguousDateFailure(),
    const MissingReminderTimeFailure(),
  ];

  group('taxonomy shape', () {
    test('has 13 local + 10 network + 4 business leaves', () {
      expect(localLeaves, hasLength(13));
      expect(networkLeaves, hasLength(10));
      expect(businessLeaves, hasLength(4));
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
    test('all 27 leaves describe to distinct labels', () {
      final all = [...localLeaves, ...networkLeaves, ...businessLeaves];
      final labels = all.map(_describe).toSet();
      expect(labels, hasLength(27));
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
        const PartialAnalysisFailure(['amount', 'date']),
        const PartialAnalysisFailure(['amount', 'date']),
      );
      expect(
        const PartialAnalysisFailure(['amount']),
        isNot(equals(const PartialAnalysisFailure(['date']))),
      );
    });
  });
}
