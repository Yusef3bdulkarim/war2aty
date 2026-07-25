import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/documents/recent_documents_repository.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/locale_store.dart';
import 'package:war2aty/core/logging/log_sink.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/upcoming_reminder.dart';
import 'package:war2aty/core/reminders/upcoming_reminder_repository.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/analysis_session_storage.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/usage_repository.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';
import 'package:war2aty/features/capture/domain/repositories/camera_permission_repository.dart';
import 'package:war2aty/features/capture/domain/services/camera_service.dart';
import 'package:war2aty/features/capture/domain/services/capture_file_cleanup.dart';
import 'package:war2aty/features/capture/domain/services/image_picker_service.dart';
import 'package:war2aty/features/capture/domain/services/image_quality_service.dart';
import 'package:war2aty/features/capture/domain/services/image_rotator.dart';
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
  final bool fails;

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

  @override
  Future<Result<DailyUsage, AppFailure>> syncUsage() async => switch (_latest) {
    Ok(:final value) when value != null => Ok(value),
    Ok() => const Err(LocalDatabaseFailure()),
    Err(:final failure) => Err(failure),
  };
}

/// A quota with [remaining] of [limit] analyses left today.
DailyUsage usageWith({required int limit, required int remaining}) {
  final today = DateTime.utc(2026, 7, 22);
  return DailyUsage(
    usageDate: today,
    dailyLimit: limit,
    usedCount: limit - remaining,
    remainingCount: remaining,
    resetsAt: today.add(const Duration(days: 1)),
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
