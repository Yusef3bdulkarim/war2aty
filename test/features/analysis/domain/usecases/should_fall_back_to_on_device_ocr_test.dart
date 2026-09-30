import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/analysis/domain/usecases/should_fall_back_to_on_device_ocr.dart';

/// Every [AppFailure] leaf with the answer F20 §1 requires for it.
///
/// The four `true` rows are the whole allowlist; every other leaf must say no.
final _expected = <AppFailure, bool>{
  // Network — the allowlist (O3, O4, O5, O7, O10).
  const AiProviderRateLimitFailure(): true,
  const RequestTimeoutFailure(): true,
  const OnlineOcrUnavailableFailure(): true,
  const NoInternetFailure(): true,
  // Network — everything else (O6, O8, O9, O11, O12, O13).
  const AnalysisServiceFailure(): false,
  const InvalidAnalysisResponseFailure(): false,
  const UnauthorizedFailure(): false,
  const AnalysisDisabledFailure(): false,
  const UnsupportedAppVersionFailure(): false,
  const InvalidRequestFailure(): false,
  DailyLimitReachedFailure(DateTime(2026, 9, 29)): false,
  const GlobalCapacityReachedFailure(): false,
  // Local.
  const AnalysisConsentDeclinedFailure(): false,
  const CameraPermissionFailure(): false,
  const GalleryAccessFailure(): false,
  const ImageQualityFailure(): false,
  const ImageProcessingFailure(): false,
  const OcrInitializationFailure(): false,
  const OcrFailure(): false,
  const NoTextDetectedFailure(): false,
  const LocalDatabaseFailure(): false,
  const LaunchFailure(): false,
  const FileEncryptionFailure(): false,
  const FileStorageFailure(): false,
  const NotificationPermissionFailure(): false,
  const NotificationSchedulingFailure(): false,
  const TtsFailure(): false,
  // Business.
  const UnsupportedDocumentFailure(): false,
  PartialAnalysisFailure(['amount']): false,
  const AmbiguousDateFailure(): false,
  const MissingReminderTimeFailure(): false,
};

void main() {
  group('shouldFallBackToOnDeviceOcr', () {
    for (final MapEntry(key: failure, value: fallsBack) in _expected.entries) {
      test('${failure.runtimeType} → ${fallsBack ? 'falls back' : 'no'}', () {
        expect(shouldFallBackToOnDeviceOcr(failure), fallsBack);
      });
    }

    test('covers every AppFailure leaf', () {
      // Same count as app_failure_test's taxonomy guard. A new leaf fails to
      // compile in the policy first; this keeps the table here in step too.
      expect(_expected, hasLength(31));
    });

    test('the allowlist is exactly the four matrix failures', () {
      final allowed = _expected.keys
          .where(shouldFallBackToOnDeviceOcr)
          .map((f) => f.runtimeType)
          .toSet();

      expect(allowed, {
        AiProviderRateLimitFailure,
        RequestTimeoutFailure,
        OnlineOcrUnavailableFailure,
        NoInternetFailure,
      });
    });
  });
}
