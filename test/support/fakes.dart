import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:war2aty/core/accessibility/high_contrast_store.dart';
import 'package:war2aty/core/accessibility/text_size.dart';
import 'package:war2aty/core/accessibility/text_size_store.dart';
import 'package:war2aty/core/analysis/analysis_consent_store.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/processing_mode_store.dart';
import 'package:war2aty/core/audio/default_reading_speed_store.dart';
import 'package:war2aty/core/audio/default_reading_voice_store.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/resume_reading_enabled_store.dart';
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/connectivity/connectivity_service.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/documents/analysis_amount.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_image_store.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/documents_repository.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/documents/recent_documents_repository.dart';
import 'package:war2aty/core/documents/required_action.dart';
import 'package:war2aty/core/documents/saved_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/locale_store.dart';
import 'package:war2aty/core/logging/log_sink.dart';
import 'package:war2aty/core/permissions/notification_permission_repository.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/local_notifications_port.dart';
import 'package:war2aty/core/reminders/notification_privacy_store.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_alert.dart';
import 'package:war2aty/core/reminders/reminder_alert_status.dart';
import 'package:war2aty/core/reminders/reminder_scheduler.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';
import 'package:war2aty/core/reminders/reminders_repository.dart';
import 'package:war2aty/core/reminders/upcoming_reminder.dart';
import 'package:war2aty/core/reminders/upcoming_reminder_repository.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/settings/app_settings_repository.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/analysis_session_storage.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/usage_repository.dart';
import 'package:war2aty/features/audio_reader/domain/entities/tts_event.dart';
import 'package:war2aty/features/audio_reader/domain/services/text_to_speech_service.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/repositories/camera_permission_repository.dart';
import 'package:war2aty/features/capture/domain/services/camera_service.dart';
import 'package:war2aty/features/capture/domain/services/capture_file_cleanup.dart';
import 'package:war2aty/features/capture/domain/services/image_cropper.dart';
import 'package:war2aty/features/capture/domain/services/image_picker_service.dart';
import 'package:war2aty/features/capture/domain/services/image_quality_service.dart';
import 'package:war2aty/features/capture/domain/services/image_rotator.dart';
import 'package:war2aty/features/capture/domain/services/perspective_corrector.dart';
import 'package:war2aty/features/capture/presentation/camera_preview_port.dart';
import 'package:war2aty/features/onboarding/domain/repositories/onboarding_repository.dart';

/// An [AppDatabase] backed by a fresh in-memory SQLite instance.
AppDatabase memoryDatabase() => AppDatabase(NativeDatabase.memory());

/// In-memory [LocaleStore] — no persistence, seedable for tests.
final class FakeLocaleStore implements LocaleStore {
  FakeLocaleStore([this._code]);

  String? _code;

  @override
  Future<String?> readLanguageCode() async => _code;

  @override
  Future<void> writeLanguageCode(String code) async => _code = code;
}

/// In-memory [NotificationPrivacyStore] (F09-T14) — no persistence,
/// seedable. `null` (the default) models a user who has never touched the
/// setting, the same as [FakeLocaleStore]'s own default.
final class FakeNotificationPrivacyStore implements NotificationPrivacyStore {
  FakeNotificationPrivacyStore([this._hide]);

  bool? _hide;

  @override
  Future<bool?> readHideSensitiveDetails() async => _hide;

  @override
  Future<void> writeHideSensitiveDetails(bool hide) async => _hide = hide;
}

/// In-memory [TextSizeStore] (F11-T05) — no persistence, seedable.
/// `null` (the default) models a user who has never touched the setting, the
/// same as [FakeLocaleStore]'s own default.
final class FakeTextSizeStore implements TextSizeStore {
  FakeTextSizeStore([this._size]);

  TextSize? _size;

  @override
  Future<TextSize?> readSize() async => _size;

  @override
  Future<void> writeSize(TextSize size) async => _size = size;
}

/// In-memory [HighContrastStore] (F11-T06) — no persistence, seedable.
/// `null` (the default) models a user who has never touched the setting, the
/// same as [FakeTextSizeStore]'s own default.
final class FakeHighContrastStore implements HighContrastStore {
  FakeHighContrastStore([this._enabled]);

  bool? _enabled;

  @override
  Future<bool?> readEnabled() async => _enabled;

  @override
  Future<void> writeEnabled(bool enabled) async => _enabled = enabled;
}

/// In-memory [AnalysisConsentStore] (F11-T02) — no persistence, seedable.
/// `null` (the default) models a user who has never touched the setting, the
/// same as [FakeLocaleStore]'s own default.
final class FakeAnalysisConsentStore implements AnalysisConsentStore {
  FakeAnalysisConsentStore([this._consent]);

  bool? _consent;

  @override
  Future<bool?> readConsent() async => _consent;

  @override
  Future<void> writeConsent(bool consent) async => _consent = consent;
}

/// In-memory [ProcessingModeStore] (F11-T03) — no persistence, seedable.
/// `null` (the default) models a user who has never touched the setting, the
/// same as [FakeAnalysisConsentStore]'s own default.
final class FakeProcessingModeStore implements ProcessingModeStore {
  FakeProcessingModeStore([this._mode]);

  ProcessingMode? _mode;

  @override
  Future<ProcessingMode?> readMode() async => _mode;

  @override
  Future<void> writeMode(ProcessingMode mode) async => _mode = mode;
}

/// In-memory [DefaultReadingSpeedStore] (F11-T07) — no persistence, seedable.
/// `null` (the default) models a user who has never touched the setting, the
/// same as [FakeProcessingModeStore]'s own default.
final class FakeDefaultReadingSpeedStore implements DefaultReadingSpeedStore {
  FakeDefaultReadingSpeedStore([this._speed]);

  ReadingSpeed? _speed;

  @override
  Future<ReadingSpeed?> readSpeed() async => _speed;

  @override
  Future<void> writeSpeed(ReadingSpeed speed) async => _speed = speed;
}

/// In-memory [DefaultReadingVoiceStore] (F11-T07) — no persistence, seedable.
/// `null` (the default) models «الصوت الافتراضي» — either untouched, or
/// explicitly reset back to it.
final class FakeDefaultReadingVoiceStore implements DefaultReadingVoiceStore {
  FakeDefaultReadingVoiceStore([this._voice]);

  TtsVoice? _voice;

  @override
  Future<TtsVoice?> readVoice() async => _voice;

  @override
  Future<void> writeVoice(TtsVoice? voice) async => _voice = voice;
}

/// In-memory [ResumeReadingEnabledStore] (F11-T07) — no persistence,
/// seedable. `null` (the default) models a user who has never touched the
/// setting, the same as [FakeProcessingModeStore]'s own default.
final class FakeResumeReadingEnabledStore implements ResumeReadingEnabledStore {
  FakeResumeReadingEnabledStore([this._enabled]);

  bool? _enabled;

  @override
  Future<bool?> readEnabled() async => _enabled;

  @override
  Future<void> writeEnabled(bool enabled) async => _enabled = enabled;
}

/// In-memory [OnboardingRepository]; can be seeded as "already seen" or made
/// to fail so the error path can be exercised.
final class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.seen = false, this.fails = false});

  bool seen;
  final bool fails;

  @override
  Future<Result<bool, AppFailure>> hasSeenOnboarding() async =>
      fails ? const Err(LocalDatabaseFailure()) : Ok(seen);

  @override
  Future<Result<void, AppFailure>> markOnboardingSeen() async {
    if (fails) return const Err(LocalDatabaseFailure());
    seen = true;
    return const Ok(null);
  }
}

/// Captures written log fields for assertions.
final class FakeLogSink implements LogSink {
  final List<Map<String, Object>> writes = [];

  @override
  void write(Map<String, Object> fields) => writes.add(fields);
}

/// In-memory [SecureStorageService] — no platform channel, seedable.
final class FakeSecureStorage implements SecureStorageService {
  FakeSecureStorage([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  /// Exposes the backing map so tests can assert what was persisted.
  Map<String, String> get contents => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Scriptable [PermissionService] — no platform channel.
///
/// [outcome] is what a check reports; [requestOutcome] is what the system
/// prompt would answer (defaults to [outcome]). Set [fails] to make every call
/// throw, so the data layer's error mapping can be exercised.
final class FakePermissionService implements PermissionService {
  FakePermissionService({
    required this.outcome,
    PermissionOutcome? requestOutcome,
    this.fails = false,
  }) : requestOutcome = requestOutcome ?? outcome;

  PermissionOutcome outcome;
  PermissionOutcome requestOutcome;
  final bool fails;

  int checkCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<PermissionOutcome> check(AppPermission permission) async {
    checkCount++;
    if (fails) throw StateError('platform channel unavailable');
    return outcome;
  }

  @override
  Future<PermissionOutcome> request(AppPermission permission) async {
    requestCount++;
    if (fails) throw StateError('platform channel unavailable');
    outcome = requestOutcome;
    return requestOutcome;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount++;
    if (fails) throw StateError('platform channel unavailable');
    return true;
  }
}

/// In-memory [CameraPermissionRepository] driven directly by the test, for
/// cubit tests that should not care how permissions are read.
final class FakeCameraPermissionRepository
    implements CameraPermissionRepository {
  FakeCameraPermissionRepository({
    required this.status,
    PermissionOutcome? afterRequest,
    this.fails = false,
  }) : afterRequest = afterRequest ?? status;

  PermissionOutcome status;
  PermissionOutcome afterRequest;

  /// Mutable like [status] — a test can flip a fake that started healthy to
  /// simulate a platform failure on a later call (e.g. a refresh after a
  /// successful load), not just at construction.
  bool fails;

  int openSettingsCount = 0;

  @override
  Future<Result<PermissionOutcome, AppFailure>> currentStatus() async =>
      fails ? const Err(CameraPermissionFailure()) : Ok(status);

  @override
  Future<Result<PermissionOutcome, AppFailure>> request() async {
    if (fails) return const Err(CameraPermissionFailure());
    status = afterRequest;
    return Ok(status);
  }

  @override
  Future<Result<bool, AppFailure>> openSettings() async {
    openSettingsCount++;
    return fails ? const Err(CameraPermissionFailure()) : const Ok(true);
  }
}

/// In-memory [NotificationPermissionRepository] (F09-T09), the same shape as
/// [FakeCameraPermissionRepository].
final class FakeNotificationPermissionRepository
    implements NotificationPermissionRepository {
  FakeNotificationPermissionRepository({
    this.status = PermissionOutcome.granted,
    PermissionOutcome? afterRequest,
    this.fails = false,
  }) : afterRequest = afterRequest ?? status;

  PermissionOutcome status;
  PermissionOutcome afterRequest;

  /// Mutable like [status] — a test can flip a fake that started healthy to
  /// simulate a platform failure on a later call (e.g. a refresh after a
  /// successful load), not just at construction (F11-T09).
  bool fails;

  int requestCount = 0;

  /// «فتح إعدادات الإشعارات» calls (F11-T09).
  int openSettingsCount = 0;

  @override
  Future<Result<PermissionOutcome, AppFailure>> currentStatus() async =>
      fails ? const Err(NotificationPermissionFailure()) : Ok(status);

  @override
  Future<Result<PermissionOutcome, AppFailure>> request() async {
    requestCount++;
    if (fails) return const Err(NotificationPermissionFailure());
    status = afterRequest;
    return Ok(status);
  }

  @override
  Future<Result<bool, AppFailure>> openSettings() async {
    openSettingsCount++;
    return fails ? const Err(NotificationPermissionFailure()) : const Ok(true);
  }
}

/// Scriptable [CameraService] — no plugin, no real device.
///
/// [initFails] / [captureFails] drive the two error paths; [photo] is what a
/// successful shot returns. The counters let a test assert the camera was
/// opened and released exactly as expected.
final class FakeCameraService implements CameraService {
  FakeCameraService({
    this.initFails = false,
    this.captureFails = false,
    this.photo = const CapturedPhoto('/tmp/shot.jpg'),
  });

  bool initFails;
  bool captureFails;
  final CapturedPhoto photo;

  /// When set, [initialize] waits on it before returning — lets a test hold the
  /// camera "opening" and interleave a suspend/close with it.
  Completer<void>? initializeGate;

  int initializeCount = 0;
  int captureCount = 0;
  int disposeCount = 0;

  @override
  Future<Result<void, AppFailure>> initialize() async {
    initializeCount++;
    final gate = initializeGate;
    if (gate != null) await gate.future;
    return initFails ? const Err(ImageProcessingFailure()) : const Ok(null);
  }

  @override
  Future<Result<CapturedPhoto, AppFailure>> capturePhoto() async {
    captureCount++;
    return captureFails ? const Err(ImageProcessingFailure()) : Ok(photo);
  }

  @override
  Future<void> dispose() async => disposeCount++;
}

/// Scriptable [ImagePickerService] — no plugin, no OS picker.
///
/// Defaults to a successful pick; set [cancelled] to model the user backing
/// out, or [fails] to model the picker failing to open.
final class FakeImagePickerService implements ImagePickerService {
  FakeImagePickerService({
    this.photo = const CapturedPhoto('/tmp/picked.jpg'),
    this.cancelled = false,
    this.fails = false,
  });

  final CapturedPhoto photo;
  bool cancelled;
  bool fails;

  /// When set, the pick waits on it before returning — lets a test hold the
  /// picker "open" so the gallery route stays put.
  Completer<void>? gate;

  int pickCount = 0;

  @override
  Future<Result<CapturedPhoto?, AppFailure>> pickSingleImage() async {
    pickCount++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (fails) return const Err(GalleryAccessFailure());
    return Ok(cancelled ? null : photo);
  }
}

/// Scriptable [ImageQualityService] — returns a fixed quality result or fails.
final class FakeImageQualityService implements ImageQualityService {
  FakeImageQualityService({
    this.result = const ImageQualityResult(
      overall: ImageQuality.good,
      blur: ImageQuality.good,
      resolution: ImageQuality.good,
      brightness: ImageQuality.good,
    ),
    this.fails = false,
  });

  ImageQualityResult result;
  bool fails;

  int assessCount = 0;
  CapturedPhoto? lastPhoto;

  @override
  Future<Result<ImageQualityResult, AppFailure>> assess(
    CapturedPhoto photo,
  ) async {
    assessCount++;
    lastPhoto = photo;
    if (fails) return const Err(ImageProcessingFailure());
    return Ok(result);
  }
}

/// Scriptable [ImageRotator] — records the requested turns, returns a fixed
/// output or a failure, without touching the `image` package or the disk.
final class FakeImageRotator implements ImageRotator {
  FakeImageRotator({
    this.output = const CapturedPhoto('/tmp/rotated.jpg'),
    this.fails = false,
  });

  final CapturedPhoto output;
  bool fails;

  int rotateCount = 0;
  int? lastQuarterTurns;

  @override
  Future<Result<CapturedPhoto, AppFailure>> rotate(
    CapturedPhoto photo,
    int quarterTurns,
  ) async {
    rotateCount++;
    lastQuarterTurns = quarterTurns;
    if (fails) return const Err(ImageProcessingFailure());
    // A no-op rotation returns the original, mirroring the real rotator.
    return Ok(quarterTurns % 4 == 0 ? photo : output);
  }
}

/// Scriptable [ImageCropper] — no `image` package/isolate work.
final class FakeImageCropper implements ImageCropper {
  FakeImageCropper({this.output, this.fails = false});

  /// The cropped photo to return. `null` means "hand the input back
  /// unchanged", mirroring the real cropper's [UnitRect.isFull] no-op.
  CapturedPhoto? output;
  bool fails;

  int cropCount = 0;
  CapturedPhoto? lastPhoto;
  UnitRect? lastRegion;

  @override
  Future<Result<CapturedPhoto, AppFailure>> crop(
    CapturedPhoto photo,
    UnitRect region,
  ) async {
    cropCount++;
    lastPhoto = photo;
    lastRegion = region;
    if (fails) return const Err(ImageProcessingFailure());
    // A no-op crop returns the original, mirroring the real cropper.
    return Ok(region.isFull ? photo : (output ?? photo));
  }
}

/// Scriptable [ConnectivityService] — no platform channel.
///
/// Defaults to online. Set [fails] to model a plugin-channel error, which
/// [DecideAnalysisRoute] treats as offline rather than letting it escape.
final class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.connected = true, this.fails = false});

  bool connected;
  bool fails;

  @override
  Future<bool> hasConnectivity() async {
    if (fails) throw StateError('platform channel unavailable');
    return connected;
  }
}

/// Scriptable [PerspectiveCorrector] — no `doclens` plugin.
///
/// Defaults to handing the photo back untouched, as if no document-like quad
/// was found. Set [output] to model a successful crop, or [fails] for the
/// typed-failure path.
final class FakePerspectiveCorrector implements PerspectiveCorrector {
  FakePerspectiveCorrector({this.output, this.fails = false});

  /// The corrected photo to return. `null` means "hand the input back
  /// unchanged", mirroring the real corrector's no-quad-detected case.
  CapturedPhoto? output;
  bool fails;

  int correctCount = 0;
  CapturedPhoto? lastPhoto;

  @override
  Future<Result<CapturedPhoto, AppFailure>> correct(CapturedPhoto photo) async {
    correctCount++;
    lastPhoto = photo;
    if (fails) return const Err(ImageProcessingFailure());
    return Ok(output ?? photo);
  }
}

/// A [CameraPreviewPort] that paints a plain marker instead of a live feed, so
/// the viewfinder can be widget-tested without a camera.
final class FakeCameraPreview implements CameraPreviewPort {
  const FakeCameraPreview();

  /// Key the viewfinder test looks for to confirm the live feed is shown.
  static const Key key = Key('fake-camera-preview');

  @override
  Widget build(BuildContext context) => const SizedBox.expand(
    child: ColoredBox(color: Color(0xFF000000), key: key),
  );
}

/// In-memory [UsageRepository] whose stream the test drives by hand.
///
/// Close it with [dispose] (or `addTearDown`) so the controller does not
/// outlive the test.
final class FakeUsageRepository implements UsageRepository {
  FakeUsageRepository({DailyUsage? seed}) {
    if (seed != null) emit(seed);
  }

  final _controller =
      StreamController<Result<DailyUsage?, AppFailure>>.broadcast();
  Result<DailyUsage?, AppFailure> _latest = const Ok(null);

  /// Pushes a new quota to listeners.
  void emit(DailyUsage? usage) {
    _latest = Ok(usage);
    if (_controller.hasListener) _controller.add(_latest);
  }

  /// Pushes a failure to listeners.
  void emitFailure([AppFailure failure = const LocalDatabaseFailure()]) {
    _latest = Err(failure);
    if (_controller.hasListener) _controller.add(_latest);
  }

  Future<void> dispose() => _controller.close();

  /// How many times the stream has been subscribed to — a double subscription
  /// is a leak, so tests assert on this directly.
  int listenCount = 0;

  @override
  Stream<Result<DailyUsage?, AppFailure>> watchUsage() async* {
    listenCount++;
    yield _latest;
    yield* _controller.stream;
  }

  @override
  Future<Result<DailyUsage?, AppFailure>> cachedUsage() async => _latest;

  /// How many times [syncUsage] has been called — tests assert on this to
  /// confirm a sync did (or deliberately did not) happen.
  int syncCallCount = 0;

  @override
  Future<Result<DailyUsage, AppFailure>> syncUsage() async {
    syncCallCount++;
    return switch (_latest) {
      Ok(:final value) when value != null => Ok(value),
      Ok() => const Err(LocalDatabaseFailure()),
      Err(:final failure) => Err(failure),
    };
  }
}

/// A quota with [remaining] of [limit] analyses left today.
DailyUsage usageWith({
  required int limit,
  required int remaining,
  bool azureOcrEnabled = false,
}) {
  final today = DateTime.utc(2026, 7, 22);
  return DailyUsage(
    usageDate: today,
    dailyLimit: limit,
    usedCount: limit - remaining,
    remainingCount: remaining,
    resetsAt: today.add(const Duration(days: 1)),
    azureOcrEnabled: azureOcrEnabled,
  );
}

/// In-memory [RecentDocumentsRepository] the test drives by hand.
final class FakeRecentDocumentsRepository implements RecentDocumentsRepository {
  FakeRecentDocumentsRepository({List<RecentDocument>? seed}) {
    if (seed != null) emit(seed);
  }

  final _controller =
      StreamController<Result<List<RecentDocument>, AppFailure>>.broadcast();
  Result<List<RecentDocument>, AppFailure> _latest = const Ok([]);

  /// The limit Home asked for, so tests can assert it is honoured.
  int? requestedLimit;

  void emit(List<RecentDocument> documents) {
    _latest = Ok(documents);
    if (_controller.hasListener) _controller.add(_latest);
  }

  void emitFailure([AppFailure failure = const LocalDatabaseFailure()]) {
    _latest = Err(failure);
    if (_controller.hasListener) _controller.add(_latest);
  }

  Future<void> dispose() => _controller.close();

  /// See [FakeUsageRepository.listenCount].
  int listenCount = 0;

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchRecent({
    int limit = 3,
  }) async* {
    listenCount++;
    requestedLimit = limit;
    yield _latest;
    yield* _controller.stream;
  }
}

/// A saved document for tests.
RecentDocument documentWith({
  String id = 'doc-1',
  String title = 'فاتورة كهرباء شهر أغسطس',
  DocumentCategory category = DocumentCategory.invoice,
  DocumentStorageMode storageMode = DocumentStorageMode.resultOnly,
}) {
  return RecentDocument(
    id: id,
    title: title,
    category: category,
    storageMode: storageMode,
    savedAt: DateTime.utc(2026, 7, 22, 10),
  );
}

/// A saved document's full record, for tests that need more than
/// [documentWith]'s summary — the details screen (F08-T08).
///
/// [kind] rather than a category: [SavedDocument.analysis] carries no
/// category of its own — it is derived from the kind, the same as the real
/// entity.
SavedDocument savedDocumentWith({
  String id = 'doc-1',
  String title = 'فاتورة كهرباء شهر أغسطس',
  DocumentKind kind = DocumentKind.invoice,
  AnalysisStatus status = AnalysisStatus.success,
  DocumentStorageMode storageMode = DocumentStorageMode.resultOnly,
  String? note,
  AnalysisSummary summary = const AnalysisSummary(
    short: 'خلاصة سريعة.',
    detailed: 'شرح تفصيلي للورقة.',
  ),
  List<KeyInformation> keyInformation = const [],
  List<AnalysisDate> dates = const [],
  List<AnalysisAmount> amounts = const [],
  List<RequiredAction> actions = const [],
  List<AnalysisWarning> warnings = const [],
  String extractedText = 'النص المستخرج من الورقة.',
}) {
  return SavedDocument(
    id: id,
    analysis: DocumentAnalysis(
      sessionId: 'session-1',
      status: status,
      kind: kind,
      title: title,
      kindConfidence: ConfidenceBand.high,
      summary: summary,
      keyInformation: keyInformation,
      dates: dates,
      amounts: amounts,
      actions: actions,
      warnings: warnings,
    ),
    extractedText: extractedText,
    storageMode: storageMode,
    note: note,
    savedAt: DateTime.utc(2026, 7, 22, 10),
    updatedAt: DateTime.utc(2026, 7, 22, 10),
  );
}

/// In-memory [UpcomingReminderRepository] the test drives by hand.
final class FakeUpcomingReminderRepository
    implements UpcomingReminderRepository {
  FakeUpcomingReminderRepository({UpcomingReminder? seed}) {
    if (seed != null) emit(seed);
  }

  final _controller =
      StreamController<Result<UpcomingReminder?, AppFailure>>.broadcast();
  Result<UpcomingReminder?, AppFailure> _latest = const Ok(null);

  /// See [FakeUsageRepository.listenCount].
  int listenCount = 0;

  void emit(UpcomingReminder? reminder) {
    _latest = Ok(reminder);
    if (_controller.hasListener) _controller.add(_latest);
  }

  void emitFailure([AppFailure failure = const LocalDatabaseFailure()]) {
    _latest = Err(failure);
    if (_controller.hasListener) _controller.add(_latest);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<Result<UpcomingReminder?, AppFailure>> watchNext() async* {
    listenCount++;
    yield _latest;
    yield* _controller.stream;
  }
}

/// A reminder due at [dueAt] (UTC).
UpcomingReminder reminderWith({
  String id = 'rem-1',
  String title = 'دفع فاتورة الكهرباء',
  DateTime? dueAt,
}) {
  return UpcomingReminder(
    id: id,
    title: title,
    dueAt: dueAt ?? DateTime.utc(2026, 7, 22, 8),
  );
}

/// Scriptable [CaptureFileCleanup] — records the paths it was asked to delete.
final class FakeCaptureFileCleanup implements CaptureFileCleanup {
  final List<List<String>> deleteCalls = [];

  @override
  Future<void> deleteFiles(List<String> paths) async => deleteCalls.add(paths);
}

/// Scriptable [AnalysisSessionStorage] — no filesystem, returns a fixed session
/// or a failure.
final class FakeAnalysisSessionStorage implements AnalysisSessionStorage {
  FakeAnalysisSessionStorage({
    this.sessionId = 'test-session-id',
    this.fails = false,
  });

  final String sessionId;
  bool fails;

  int createCount = 0;
  CapturedPhoto? lastPhoto;

  @override
  Future<Result<int, AppFailure>> deleteStaleSessions() async => const Ok(0);

  @override
  Future<Result<AnalysisSession, AppFailure>> createSession(
    CapturedPhoto photo,
  ) async {
    createCount++;
    lastPhoto = photo;
    if (fails) return const Err(FileStorageFailure());
    return Ok(
      AnalysisSession(
        id: sessionId,
        imagePath: '/cache/analysis_sessions/$sessionId/processed.jpg',
      ),
    );
  }
}

/// Scriptable [DocumentImageStore] — no filesystem, records what it was asked
/// to encrypt and delete.
final class FakeDocumentImageStore implements DocumentImageStore {
  FakeDocumentImageStore({this.fails = false});

  bool fails;

  /// `documentId -> sourcePath` for every call to [encryptAndStore].
  final Map<String, String> stored = {};

  /// Every id passed to [delete], in order.
  final List<String> deletedIds = [];

  @override
  Future<Result<String, AppFailure>> encryptAndStore({
    required String documentId,
    required String sourcePath,
  }) async {
    if (fails) return const Err(FileEncryptionFailure());
    stored[documentId] = sourcePath;
    return Ok('/private/documents/$documentId/original.enc');
  }

  @override
  Future<void> delete(String documentId) async => deletedIds.add(documentId);

  /// Whether [deleteAll] was called (F11-T11).
  bool deleteAllCalled = false;

  @override
  Future<void> deleteAll() async => deleteAllCalled = true;
}

/// In-memory [DocumentsRepository] the test drives by hand — the read side
/// (`watchDocuments`) works like [FakeRecentDocumentsRepository]; the two
/// write methods just record what they were called with, for tests that
/// exercise both sides of the interface.
final class FakeDocumentsRepository implements DocumentsRepository {
  FakeDocumentsRepository({List<RecentDocument>? seed}) {
    if (seed != null) emit(seed);
  }

  final _controller =
      StreamController<Result<List<RecentDocument>, AppFailure>>.broadcast();
  Result<List<RecentDocument>, AppFailure> _latest = const Ok([]);

  /// See [FakeUsageRepository.listenCount].
  int listenCount = 0;

  void emit(List<RecentDocument> documents) {
    _latest = Ok(documents);
    if (_controller.hasListener) _controller.add(_latest);
  }

  void emitFailure([AppFailure failure = const LocalDatabaseFailure()]) {
    _latest = Err(failure);
    if (_controller.hasListener) _controller.add(_latest);
  }

  Future<void> dispose() =>
      Future.wait([_controller.close(), _documentController.close()]);

  /// The title filter the cubit last asked for (F08-T06). This fake never
  /// filters by it — that matching logic is the DAO's, and is covered by
  /// `documents_dao_test.dart` — it only records what it was asked for so a
  /// cubit test can assert the request without re-implementing the match.
  String? requestedTitleQuery;

  /// The category filter the cubit last asked for (F08-T07). Same
  /// record-only contract as [requestedTitleQuery].
  DocumentCategory? requestedCategory;

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchDocuments({
    String? titleQuery,
    DocumentCategory? category,
  }) async* {
    listenCount++;
    requestedTitleQuery = titleQuery;
    requestedCategory = category;
    yield _latest;
    yield* _controller.stream;
  }

  final _documentController =
      StreamController<Result<SavedDocument?, AppFailure>>.broadcast();
  Result<SavedDocument?, AppFailure> _latestDocument = const Ok(null);

  /// The id [watchDocument] was last asked for (F08-T08).
  String? requestedDocumentId;

  /// See [FakeUsageRepository.listenCount], for [watchDocument] instead of
  /// [watchDocuments].
  int documentListenCount = 0;

  void emitDocument(SavedDocument? document) {
    _latestDocument = Ok(document);
    if (_documentController.hasListener) {
      _documentController.add(_latestDocument);
    }
  }

  void emitDocumentFailure([
    AppFailure failure = const LocalDatabaseFailure(),
  ]) {
    _latestDocument = Err(failure);
    if (_documentController.hasListener) {
      _documentController.add(_latestDocument);
    }
  }

  @override
  Stream<Result<SavedDocument?, AppFailure>> watchDocument(String id) async* {
    documentListenCount++;
    requestedDocumentId = id;
    yield _latestDocument;
    yield* _documentController.stream;
  }

  Result<String, AppFailure> saveOutcome = const Ok('doc-1');

  @override
  Future<Result<String, AppFailure>> saveResultOnly({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) async => saveOutcome;

  @override
  Future<Result<String, AppFailure>> saveWithImage({
    required DocumentAnalysis analysis,
    required String extractedText,
    required String imagePath,
  }) async => saveOutcome;

  /// Outcome of [updateDocument]. Default success; set to an [Err] to test
  /// failures (F08-T10).
  Result<void, AppFailure> updateOutcome = const Ok(null);

  /// The title [updateDocument] was last called with.
  String? lastTitleSet;

  /// The category [updateDocument] was last called with.
  DocumentCategory? lastCategorySet;

  @override
  Future<Result<void, AppFailure>> updateDocument(
    String id, {
    String? title,
    DocumentCategory? category,
  }) async {
    lastTitleSet = title;
    lastCategorySet = category;
    return updateOutcome;
  }

  /// Outcome of [deleteDocument]. Default success; set to an [Err] to test
  /// failures (F08-T11).
  Result<void, AppFailure> deleteOutcome = const Ok(null);

  /// The id [deleteDocument] was last called with.
  String? lastDeletedId;

  @override
  Future<Result<void, AppFailure>> deleteDocument(String id) async {
    lastDeletedId = id;
    return deleteOutcome;
  }

  /// Outcome of [setNote]. Default success; set to an [Err] to test failures.
  Result<void, AppFailure> setNoteOutcome = const Ok(null);

  /// The note [setNote] was last called with (F08-T09).
  String? lastNoteSet;

  /// Whether [setNote] was called with `null` (a delete).
  bool noteDeleted = false;

  @override
  Future<Result<void, AppFailure>> setNote(String id, String? note) async {
    lastNoteSet = note;
    noteDeleted = note == null;
    return setNoteOutcome;
  }

  /// Outcome of [deleteAllDocuments]. Default success; set to an [Err] to
  /// test failures (F11-T11).
  Result<void, AppFailure> deleteAllOutcome = const Ok(null);

  /// Whether [deleteAllDocuments] was called.
  bool deleteAllCalled = false;

  @override
  Future<Result<void, AppFailure>> deleteAllDocuments() async {
    deleteAllCalled = true;
    return deleteAllOutcome;
  }
}

/// A minimal, always-valid [Reminder] a fake can hand back — real field
/// values matter less than that every required one is present.
Reminder fakeReminder({
  String id = 'r1',
  String? documentId,
  String title = 'دفع فاتورة الكهرباء',
  ReminderStatus status = ReminderStatus.pending,
  bool isManual = false,
  List<DateTime> alertTimes = const [],
}) => Reminder(
  id: id,
  documentId: documentId,
  title: title,
  eventDate: DateTime(2026, 8, 25),
  eventMinuteOfDay: 600,
  status: status,
  isManual: isManual,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  alerts: [
    // Prefixed with the reminder's own id: two `fakeReminder()`s in the same
    // test must not collide on the same alert id (and so the same
    // `notificationIdOf` hash) just because both start counting from 0.
    for (final (i, time) in alertTimes.indexed)
      ReminderAlert(
        id: '$id-a$i',
        reminderId: id,
        scheduledAt: time,
        status: ReminderAlertStatus.scheduled,
      ),
  ],
);

/// Records what it is asked to do rather than persisting anything, for
/// cubit tests that must not depend on Drift (F09).
final class FakeRemindersRepository implements RemindersRepository {
  final _controller =
      StreamController<Result<List<Reminder>, AppFailure>>.broadcast();
  Result<List<Reminder>, AppFailure> _latest = const Ok([]);

  final _reminderControllers =
      <String, StreamController<Result<Reminder?, AppFailure>>>{};
  final _latestReminder = <String, Result<Reminder?, AppFailure>>{};

  void emit(List<Reminder> reminders) {
    _latest = Ok(reminders);
    if (_controller.hasListener) _controller.add(_latest);
  }

  void emitFailure([AppFailure failure = const LocalDatabaseFailure()]) {
    _latest = Err(failure);
    if (_controller.hasListener) _controller.add(_latest);
  }

  void emitReminder(String id, Reminder? reminder) {
    _latestReminder[id] = Ok(reminder);
    _reminderControllers[id]?.add(_latestReminder[id]!);
  }

  void emitReminderFailure(
    String id, [
    AppFailure failure = const LocalDatabaseFailure(),
  ]) {
    _latestReminder[id] = Err(failure);
    _reminderControllers[id]?.add(_latestReminder[id]!);
  }

  Future<void> dispose() async {
    await _controller.close();
    for (final c in _reminderControllers.values) {
      await c.close();
    }
  }

  @override
  Stream<Result<List<Reminder>, AppFailure>> watchReminders() async* {
    yield _latest;
    yield* _controller.stream;
  }

  @override
  Stream<Result<Reminder?, AppFailure>> watchReminder(String id) async* {
    final controller = _reminderControllers.putIfAbsent(
      id,
      StreamController<Result<Reminder?, AppFailure>>.broadcast,
    );
    yield _latestReminder[id] ?? const Ok(null);
    yield* controller.stream;
  }

  /// Outcome of [createReminder]. Default success with [fakeReminder].
  Result<Reminder, AppFailure> createOutcome = Ok(fakeReminder());

  /// The arguments [createReminder] was last called with.
  String? lastCreatedTitle;
  String? lastCreatedDescription;
  String? lastCreatedDocumentId;
  DateTime? lastCreatedEventDate;
  int? lastCreatedEventMinuteOfDay;
  bool? lastCreatedIsManual;
  List<DateTime>? lastCreatedAlertTimes;

  @override
  Future<Result<Reminder, AppFailure>> createReminder({
    String? documentId,
    required String title,
    String? description,
    required DateTime eventDate,
    int? eventMinuteOfDay,
    required bool isManual,
    required List<DateTime> alertTimes,
  }) async {
    lastCreatedDocumentId = documentId;
    lastCreatedTitle = title;
    lastCreatedDescription = description;
    lastCreatedEventDate = eventDate;
    lastCreatedEventMinuteOfDay = eventMinuteOfDay;
    lastCreatedIsManual = isManual;
    lastCreatedAlertTimes = alertTimes;
    return createOutcome;
  }

  Result<void, AppFailure> updateOutcome = const Ok(null);
  List<DateTime>? lastUpdatedAlertTimes;

  @override
  Future<Result<void, AppFailure>> updateReminder(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
    List<DateTime>? alertTimes,
  }) async {
    lastUpdatedAlertTimes = alertTimes;
    return updateOutcome;
  }

  Result<void, AppFailure> completeOutcome = const Ok(null);
  String? lastCompletedId;

  @override
  Future<Result<void, AppFailure>> completeReminder(String id) async {
    lastCompletedId = id;
    return completeOutcome;
  }

  Result<void, AppFailure> snoozeOutcome = const Ok(null);
  String? lastSnoozedId;
  DateTime? lastSnoozedTo;

  @override
  Future<Result<void, AppFailure>> snoozeReminder(
    String id,
    DateTime newAlertTime,
  ) async {
    lastSnoozedId = id;
    lastSnoozedTo = newAlertTime;
    return snoozeOutcome;
  }

  Result<void, AppFailure> deleteOutcome = const Ok(null);
  String? lastDeletedId;

  @override
  Future<Result<void, AppFailure>> deleteReminder(String id) async {
    lastDeletedId = id;
    return deleteOutcome;
  }

  Result<void, AppFailure> deleteAllOutcome = const Ok(null);
  bool deleteAllCalled = false;

  @override
  Future<Result<void, AppFailure>> deleteAllReminders() async {
    deleteAllCalled = true;
    return deleteAllOutcome;
  }

  Result<List<Reminder>, AppFailure> pendingOutcome = const Ok([]);

  @override
  Future<Result<List<Reminder>, AppFailure>> pendingReminders() async =>
      pendingOutcome;

  Result<List<Reminder>, AppFailure> forDocumentOutcome = const Ok([]);

  @override
  Future<Result<List<Reminder>, AppFailure>> remindersForDocument(
    String documentId,
  ) async => forDocumentOutcome;

  Result<void, AppFailure> setAlertStatusOutcome = const Ok(null);
  String? lastAlertStatusId;
  ReminderAlertStatus? lastAlertStatus;

  @override
  Future<Result<void, AppFailure>> setAlertStatus(
    String alertId,
    ReminderAlertStatus status,
  ) async {
    lastAlertStatusId = alertId;
    lastAlertStatus = status;
    return setAlertStatusOutcome;
  }
}

/// In-memory [LocalNotificationsPort] (F09-T10) — no plugin, no platform
/// channel. Tracks what is "scheduled" as a plain map so a scheduler test
/// can assert on it directly.
final class FakeLocalNotificationsPort implements LocalNotificationsPort {
  int initializeCount = 0;

  /// id -> (title, body) of everything currently "scheduled".
  final Map<int, (String, String?)> scheduled = {};

  /// The `at` each id was last scheduled for, kept alongside [scheduled] so
  /// a test can assert the instant without a bespoke record type per call.
  final Map<int, DateTime> scheduledAt = {};

  /// Set of ids on which [schedule] should throw, to exercise the
  /// scheduler's own failure handling.
  final Set<int> failingIds = {};

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    String? body,
  }) async {
    if (failingIds.contains(id)) {
      throw StateError('scheduling failed for $id');
    }
    scheduled[id] = (title, body);
    scheduledAt[id] = at;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    scheduledAt.remove(id);
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}

/// Records how often [reconcile] is called, for a test that only needs to
/// know a caller asked — not what an actual scheduler would then do.
final class FakeReminderScheduler implements ReminderScheduler {
  int reconcileCount = 0;
  Result<int, AppFailure> outcome = const Ok(0);

  @override
  Future<Result<int, AppFailure>> reconcile() async {
    reconcileCount++;
    return outcome;
  }
}

/// Scriptable [AppSettingsRepository] — no Drift, records whether it was
/// asked to clear everything (F11-T11).
final class FakeAppSettingsRepository implements AppSettingsRepository {
  Result<void, AppFailure> clearOutcome = const Ok(null);
  bool clearCalled = false;

  @override
  Future<Result<void, AppFailure>> clearAllSettingsAndUsageCache() async {
    clearCalled = true;
    return clearOutcome;
  }
}

/// Scriptable [TextToSpeechService] — no plugin, no OS engine (F10).
///
/// [speakFails] / [stopFails] drive the two error paths a cubit test needs;
/// [spoken] records every text handed to [speak], in order, so a test can
/// assert what was actually read without re-implementing `BuildReadingText`.
final class FakeTextToSpeechService implements TextToSpeechService {
  FakeTextToSpeechService({
    this.speakFails = false,
    this.stopFails = false,
    this.pauseFails = false,
    this.resumeFails = false,
    this.setSpeechRateFails = false,
    this.voices = const [],
    this.getVoicesFails = false,
    this.setVoiceFails = false,
  });

  bool speakFails;
  bool stopFails;
  bool pauseFails;
  bool resumeFails;
  bool setSpeechRateFails;

  /// What [getVoices] answers with (F10-T07) — empty by default, the same as
  /// a device the app has not yet asked, or one with nothing installed.
  List<TtsVoice> voices;
  bool getVoicesFails;
  bool setVoiceFails;

  final List<String> spoken = [];
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;

  /// Every rate handed to [setSpeechRate], in order (F10-T06) — so a test can
  /// assert the chosen `ReadingSpeed` actually reached the engine.
  final List<double> speechRates = [];

  /// Every voice handed to [setVoice], in order (F10-T07) — so a test can
  /// assert which default voice actually reached the engine.
  final List<TtsVoice> voicesSet = [];

  final _events = StreamController<TtsEvent>.broadcast();

  /// Pushes [event] to whatever is listening on [events] — lets a test drive
  /// playback lifecycle notifications (F10-T08) the same way a real engine's
  /// native handlers would.
  void emitEvent(TtsEvent event) => _events.add(event);

  @override
  Future<Result<void, AppFailure>> speak(String text) async {
    spoken.add(text);
    return speakFails ? const Err(TtsFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> pause() async {
    pauseCount++;
    return pauseFails ? const Err(TtsFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> resume() async {
    resumeCount++;
    return resumeFails ? const Err(TtsFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> stop() async {
    stopCount++;
    return stopFails ? const Err(TtsFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> setSpeechRate(double rate) async {
    speechRates.add(rate);
    return setSpeechRateFails ? const Err(TtsFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> setVoice(TtsVoice voice) async {
    voicesSet.add(voice);
    return setVoiceFails ? const Err(TtsFailure()) : const Ok(null);
  }

  @override
  Future<Result<List<TtsVoice>, AppFailure>> getVoices() async =>
      getVoicesFails ? const Err(TtsFailure()) : Ok(voices);

  @override
  Stream<TtsEvent> get events => _events.stream;

  Future<void> dispose() => _events.close();
}
