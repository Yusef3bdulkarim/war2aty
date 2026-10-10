/// Boots the whole app for an end-to-end journey test (F27-T17).
///
/// Everything in this file exists to make one thing possible: driving the
/// shipped app — the real `configureDependencies` graph, the real router, the
/// real Drift database, the real Dio client with its real interceptors, the
/// real repositories, mappers, validators and schedulers — from a tap on Home
/// to a row in the database, and to assert on what came out at the far end.
///
/// What is faked is only where the app meets something outside itself:
///
/// - **the platform**: camera, photo picker, Tesseract, the `image` package's
///   rotate/crop/quality work, the notifications plugin, TTS, permissions,
///   connectivity, secure storage, the session directory and the encrypted
///   image store;
/// - **the network**: one [FakeEdgeFunctions] HTTP adapter under the app's own
///   Dio, so `get-usage`, `ocr-document` and `analyze-document` answer with
///   real wire JSON — including the bundled `invoice.json` fixture — and every
///   request the app sent can be read back and asserted on.
///
/// Nothing between those two edges is replaced. That is the point: a journey
/// test that stubbed `AnalysisRepository` would prove the screens talk to each
/// other, and nothing about the DTOs, the failure mapping, the quota cache or
/// the notification the user actually gets.
///
/// ## Two things a caller has to know
///
/// 1. **The identity is the real stub, not Supabase.** The harness runs a
///    *configured* dev environment so DI picks the real Edge Function
///    datasources, then registers [StubAuthRepository] over it — the same
///    class an unconfigured build uses. `Supabase.initialize` is a process
///    global that `bootstrap` owns, and a test must not call it.
/// 2. **The online route needs the real clock.** The online reading reads the
///    photo off disk and base64-encodes it in `Isolate.run`
///    (`DefaultAnalysisRepository._buildImageRequest`), and neither completes
///    inside `testWidgets`'s `FakeAsync` zone. Use [AppHarness.settleWithIo]
///    around any step that crosses it, or the journey hangs on the review
///    screen's spinner. The offline route touches neither.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/core/analysis/analysis_consent_store.dart';
import 'package:war2aty/core/connectivity/connectivity_service.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/documents/document_image_store.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/reminders/local_notifications_port.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/analysis_session_storage.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';
import 'package:war2aty/core/time/cairo_day.dart';
import 'package:war2aty/core/usage/usage_remote_data_source.dart';
import 'package:war2aty/features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';
import 'package:war2aty/features/audio_reader/domain/services/text_to_speech_service.dart';
import 'package:war2aty/features/bootstrap/data/repositories/stub_auth_repository.dart';
import 'package:war2aty/features/bootstrap/domain/repositories/auth_repository.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';
import 'package:war2aty/features/capture/domain/services/capture_file_cleanup.dart';
import 'package:war2aty/features/capture/domain/services/image_cropper.dart';
import 'package:war2aty/features/capture/domain/services/image_picker_service.dart';
import 'package:war2aty/features/capture/domain/services/image_quality_service.dart';
import 'package:war2aty/features/capture/domain/services/image_rotator.dart';
import 'package:war2aty/features/capture/domain/usecases/capture_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/dispose_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/focus_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/set_camera_flash.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_cubit.dart';
import 'package:war2aty/features/ocr/domain/services/image_preprocessor.dart';
import 'package:war2aty/features/ocr/domain/services/ocr_engine.dart';
import 'package:war2aty/features/onboarding/domain/repositories/onboarding_repository.dart';

import 'fakes.dart';

/// What the on-device reader (Tesseract) "sees" by default: the vertical
/// slice's electricity bill, in the shape a real scan comes back in.
const String kDeviceOcrText =
    'شركة جنوب القاهرة لتوزيع الكهرباء\n'
    'فاتورة استهلاك شهر مارس\n'
    'رقم الحساب: 12345678\n'
    'المبلغ المطلوب: 850.50 جنيه\n'
    'آخر موعد للسداد: 15/04/2026';

/// The hour the journey's deadline carries, so the reminder form opens with
/// its default alert already in place (a date with no time has none, and the
/// save button stays disabled until the user adds one — that path is
/// `reminder_form_*`'s to cover, not this one's).
const String kJourneyDeadlineTime = '10:00';

/// How far ahead the journey's deadline sits.
///
/// Relative to today rather than fixed, because the scheduler only schedules
/// alerts still in the future and the fixture's own 2024 deadline is long
/// past. A week is wide enough that no run can land on the wrong side of it.
const Duration kJourneyDeadlineLeadTime = Duration(days: 7);

/// One call the app made to an Edge Function.
final class EdgeCall {
  EdgeCall(this.path, this.body, this.headers);

  /// Path relative to the functions base URL, e.g. `/analyze-document`.
  final String path;

  /// The decoded request body, or `null` for a GET.
  final Map<String, dynamic>? body;

  /// The headers the request actually left with — so a test can see that the
  /// real interceptors ran (`apikey`, `Authorization`, `x-request-id`).
  final Map<String, Object?> headers;
}

/// What a fake Edge Function answers with: a status and a body, or a
/// transport failure that never reaches one.
final class EdgeReply {
  const EdgeReply.json(this.statusCode, this.body) : transportFailure = null;

  /// The call fails below HTTP — a timeout, a dead socket. [statusCode] and
  /// [body] are never used.
  const EdgeReply.transportFailure(DioExceptionType this.transportFailure)
    : statusCode = 0,
      body = null;

  /// A §31 error envelope.
  factory EdgeReply.error(
    int statusCode,
    String code, {
    Map<String, Object?>? details,
  }) => EdgeReply.json(statusCode, {
    'error': {'code': code, 'message': 'test', 'details': ?details},
  });

  final int statusCode;
  final Object? body;
  final DioExceptionType? transportFailure;
}

/// The app's whole backend, as one Dio adapter.
///
/// Installed on the app's own `Dio` — so the request that arrives here has
/// been through `RequestIdInterceptor`, `ApiLogInterceptor` and
/// `AuthInterceptor` exactly as it would on a phone, and the response goes
/// back up through the real datasource, repository, validator and mapper.
///
/// Each endpoint has a default answer that makes the happy path work; a test
/// overrides only the one it is about, with [reply] (every call) or
/// [replyOnce] (this call, then back to the default).
final class FakeEdgeFunctions implements HttpClientAdapter {
  FakeEdgeFunctions({
    this.dailyLimit = 3,
    this.usedToday = 0,
    this.onlineOcrEnabled = false,
    this.analysisEnabled = true,
    Map<String, Object?>? analyzeBody,
  }) : analyzeBody = analyzeBody ?? journeyInvoiceBody();

  /// The quota this backend is holding, which `get-usage` reports and a
  /// successful `analyze-document` consumes a slot of — as the server does,
  /// so the count Home shows afterwards is the one the journey earned.
  int dailyLimit;
  int usedToday;
  bool onlineOcrEnabled;
  bool analysisEnabled;

  /// The analyze-document success body. Defaults to the bundled invoice
  /// fixture with a reminder-worthy deadline (see [journeyInvoiceBody]).
  Map<String, Object?> analyzeBody;

  /// Every call the app made, in order.
  final List<EdgeCall> calls = [];

  /// Paths asked for that this backend does not serve. A journey that reached
  /// an endpoint nobody expected should fail loudly rather than read as a
  /// service error.
  final List<String> unexpectedPaths = [];

  final Map<String, EdgeReply> _overrides = {};
  final Map<String, List<EdgeReply>> _queues = {};

  /// Answers every call to [path] with [reply], until told otherwise.
  void reply(String path, EdgeReply reply) => _overrides[path] = reply;

  /// Answers the next call to [path] with this reply, then falls back to
  /// whatever [reply] installed, or to the default. Call it more than once to
  /// queue a sequence.
  void replyOnce(String path, EdgeReply reply) =>
      (_queues[path] ??= []).add(reply);

  int get remainingToday => (dailyLimit - usedToday).clamp(0, dailyLimit);

  /// Every call to [path], in order.
  Iterable<EdgeCall> callsTo(String path) =>
      calls.where((call) => call.path == path);

  /// How many times [path] was called.
  int countOf(String path) => callsTo(path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    calls.add(EdgeCall(path, _decodeBody(options.data), {...options.headers}));

    final reply = _queues[path]?.isNotEmpty ?? false
        ? _queues[path]!.removeAt(0)
        : _overrides[path] ?? _defaultFor(path);

    if (reply.transportFailure case final failure?) {
      throw DioException(requestOptions: options, type: failure);
    }

    // The server reserves and consumes the user's slot; the app only mirrors
    // it. Only a success consumes one — a refused or failed analysis does not
    // (§31 rule 6, and the result screen's «المحاولة دي مش محسوبة»).
    if (path == kAnalyzeDocumentPath && _isSuccess(reply.statusCode)) {
      usedToday++;
    }

    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  EdgeReply _defaultFor(String path) {
    switch (path) {
      case kGetUsagePath:
        return EdgeReply.json(200, usageBody());
      case kOcrDocumentPath:
        return const EdgeReply.json(200, kOcrDocumentBody);
      case kAnalyzeDocumentPath:
        return EdgeReply.json(200, analyzeBody);
      default:
        unexpectedPaths.add(path);
        return EdgeReply.error(500, 'INTERNAL_ERROR');
    }
  }

  /// Today's quota in `get-usage`'s wire shape (API_CONTRACT §32).
  Map<String, Object?> usageBody() {
    final today = cairoDateOf(DateTime.now());
    return {
      'schema_version': '1.0',
      'usage_date':
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}',
      'daily_limit': dailyLimit,
      'used_today': usedToday,
      'remaining_today': remainingToday,
      'resets_at': nextCairoResetAfter(DateTime.now()).toIso8601String(),
      'analysis_enabled': analysisEnabled,
      'online_ocr_enabled': onlineOcrEnabled,
    };
  }

  static bool _isSuccess(int status) => status >= 200 && status < 300;

  static Map<String, dynamic>? _decodeBody(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : null;
    }
    return null;
  }
}

/// The bundled `invoice.json` fixture — a real analyze-document success body —
/// with its deadline moved to [kJourneyDeadlineLeadTime] from today and given
/// a time.
///
/// Read off disk synchronously on purpose: real file I/O inside a
/// `testWidgets` body never completes (see `flutter_test_config.dart`), and
/// this is the one place the journey needs the shipped fixture rather than a
/// JSON literal written to match it.
Map<String, Object?> journeyInvoiceBody({DateTime? deadline}) {
  final raw = File('assets/fixtures/analysis/invoice.json').readAsStringSync();
  final body = jsonDecode(raw) as Map<String, dynamic>;
  final dates = body['dates'] as List<dynamic>;
  final at = deadline ?? journeyDeadline();

  dates[0] = {
    ...dates[0] as Map<String, dynamic>,
    'date':
        '${at.year.toString().padLeft(4, '0')}-'
        '${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}',
    'time': kJourneyDeadlineTime,
  };
  return body;
}

/// The day the journey's paper is due: a week out, at date granularity.
DateTime journeyDeadline() {
  final now = DateTime.now().add(kJourneyDeadlineLeadTime);
  return DateTime(now.year, now.month, now.day);
}

/// A real `ocr-document` success body (API_CONTRACT §29b), the same shape the
/// bundled mock datasource serves.
const Map<String, Object?> kOcrDocumentBody = {
  'schema_version': '2.0',
  'session_id': 'journey-ocr-session',
  'ocr_text':
      'شركة جنوب القاهرة لتوزيع الكهرباء\n'
      'فاتورة استهلاك شهر مارس\n'
      'رقم الحساب: 12345678\n'
      'المبلغ المطلوب: 850.50 جنيه\n'
      'آخر موعد للسداد: 15/04/2026\n'
      'للاستفسار: 19980',
  'detected_languages': ['ar'],
  'candidates': {
    'dates': [
      {
        'raw_text': '15/04/2026',
        'normalized_date': '2026-04-15',
        'is_ambiguous': false,
      },
    ],
    'times': <Map<String, Object?>>[],
    'amounts': [
      {
        'raw_text': '850.50 جنيه',
        'value': 850.5,
        'currency': 'EGP',
        'is_ambiguous': false,
      },
    ],
    'phones': [
      {
        'raw_text': '19980',
        'normalized_number': '19980',
        'is_ambiguous': false,
      },
    ],
    'references': <Map<String, Object?>>[],
  },
};

/// An [AnalysisSessionStorage] that creates a session on real disk.
///
/// The online route reads the confirmed photo's bytes, so the file has to
/// exist; the offline route never opens it. Every directory created is deleted
/// again when the test ends.
final class TempAnalysisSessionStorage implements AnalysisSessionStorage {
  TempAnalysisSessionStorage(this._root);

  final Directory _root;

  /// The id of every session created, in order.
  final List<String> created = [];

  @override
  Future<Result<AnalysisSession, AppFailure>> createSession(
    CapturedPhoto photo,
  ) async {
    final id = 'journey-session-${created.length + 1}';
    created.add(id);
    final directory = Directory('${_root.path}/analysis_sessions/$id')
      ..createSync(recursive: true);
    final processed = File('${directory.path}/processed.jpg')
      ..writeAsBytesSync(File(photo.path).readAsBytesSync());
    return Ok(AnalysisSession(id: id, imagePath: processed.path));
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final directory = Directory('${_root.path}/analysis_sessions/$sessionId');
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  @override
  Future<Result<int, AppFailure>> deleteStaleSessions() async => const Ok(0);

  /// Whether the session directory for [sessionId] is still on disk.
  bool hasSession(String sessionId) =>
      Directory('${_root.path}/analysis_sessions/$sessionId').existsSync();
}

/// The booted app, with every fake the journey can drive or assert on.
final class AppHarness {
  AppHarness({
    required this.tester,
    required this.backend,
    required this.camera,
    required this.picker,
    required this.permissions,
    required this.connectivity,
    required this.ocrEngine,
    required this.notifications,
    required this.tts,
    required this.documentImages,
    required this.sessions,
    required this.database,
    required this.photoPath,
    required this.deadline,
  });

  final WidgetTester tester;
  final FakeEdgeFunctions backend;
  final FakeCameraService camera;
  final FakeImagePickerService picker;
  final FakePermissionService permissions;
  final FakeConnectivityService connectivity;
  final FakeOcrEngine ocrEngine;
  final FakeLocalNotificationsPort notifications;
  final FakeTextToSpeechService tts;
  final FakeDocumentImageStore documentImages;
  final TempAnalysisSessionStorage sessions;
  final AppDatabase database;

  /// The real file the fake camera hands back as its photo.
  final String photoPath;

  /// The deadline the journey's paper carries, resolved **once** when the app
  /// was booted. A test asserts against this rather than recomputing it: two
  /// `DateTime.now()` calls either side of local midnight would disagree, and
  /// the test would fail for the date rather than for the app.
  final DateTime deadline;

  GoRouter get router => getIt<GoRouter>();

  /// The saved papers currently in the database.
  ///
  /// A one-shot select, not the DAO's `watch…` stream: Drift delivers a
  /// stream's first value through `Timer.run`, and a timer inside a
  /// `testWidgets` body only fires when a pump advances the clock — so
  /// awaiting the stream here would hang the test rather than read the row.
  Future<List<DocumentRow>> savedDocuments() =>
      database.select(database.documents).get();

  /// The reminders currently in the database. Same one-shot read as
  /// [savedDocuments].
  Future<List<ReminderRow>> savedReminders() =>
      database.select(database.reminders).get();

  /// Every alert row, for asserting what a saved reminder scheduled.
  Future<List<ReminderAlertRow>> savedAlerts() =>
      database.select(database.reminderAlerts).get();

  /// Where the app is right now, as a path.
  String get location => router.state.uri.toString();

  /// Advances the app while letting real (non-`FakeAsync`) work complete.
  ///
  /// Two things make this necessary on the online route, and neither applies
  /// to the on-device one:
  ///
  /// - the online reading reads the photo off disk and base64-encodes it in
  ///   `Isolate.run`, and real I/O and real isolates do not complete inside a
  ///   `testWidgets` body — `runAsync` hands the framework back to the real
  ///   clock for long enough that they do;
  /// - while that is in flight the screen shows the waiting animation, which
  ///   repeats, so `pumpAndSettle` alone never returns.
  ///
  /// So it pumps in slices with real time in between until nothing is
  /// animating any more — which is the screen's own way of saying the work it
  /// was waiting on has landed — and only settles then. Spawning the isolate
  /// alone takes a few hundred real milliseconds, so a fixed number of rounds
  /// would be either flaky or slow; the early exit keeps the normal cost at
  /// about half a second, while the round budget leaves **three real seconds**
  /// for a loaded CI runner to get there.
  Future<void> settleWithIo({int maxRounds = 60}) async {
    var quietRounds = 0;
    for (var round = 0; round < maxRounds; round++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      // Two in a row, not one: a single quiet round could be a gap between
      // two animations rather than the end of the work.
      quietRounds = tester.hasRunningAnimations ? 0 : quietRounds + 1;
      if (quietRounds == 2) break;
    }
    await tester.pumpAndSettle();
  }

  /// Tears the app down inside the test body, where the clock can still run.
  ///
  /// Closing the app closes its cubits, which cancel their Drift query
  /// streams, and Drift schedules a zero-duration timer to finish that
  /// cancellation. `flutter_test` unmounts the tree itself once the body
  /// returns, but the `pump()` it follows with does not advance the clock, so
  /// that timer is still pending when the binding checks — and every journey
  /// would fail on "a Timer is still pending even after the widget tree was
  /// disposed" rather than on anything it asserted. [journeyTest] calls this;
  /// a test that boots the app by hand has to.
  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }
}

/// A journey over a freshly booted app, torn down the way one has to be.
///
/// [boot] defaults to [bootApp]'s own defaults; pass a closure to change them
/// (`boot: (tester) => bootApp(tester, onlineOcrEnabled: true)`).
void journeyTest(
  String description,
  Future<void> Function(AppHarness harness) body, {
  Future<AppHarness> Function(WidgetTester tester) boot = bootApp,
}) {
  testWidgets(description, (tester) async {
    final harness = await boot(tester);
    await body(harness);
    await harness.dispose();
  });
}

/// Boots the real app over the real dependency graph, with the boundaries
/// above faked, and settles on whatever screen it opens on.
///
/// [onlineOcrEnabled] is the server's own flag, so it decides the route the
/// same way production does: with it off (the default), a capture takes the
/// on-device pipeline; with it on and [connected] true, it takes the online
/// one.
Future<AppHarness> bootApp(
  WidgetTester tester, {
  bool onlineOcrEnabled = false,
  bool connected = true,
  PermissionOutcome permissions = PermissionOutcome.granted,
  int dailyLimit = 3,
  int usedToday = 0,
  bool analysisEnabled = true,
  bool seenOnboarding = true,
  bool? analysisConsent,
  String ocrText = kDeviceOcrText,
  DateTime? deadline,
  ImageQualityResult quality = const ImageQualityResult(
    overall: ImageQuality.good,
    blur: ImageQuality.good,
    resolution: ImageQuality.good,
    brightness: ImageQuality.good,
  ),
}) async {
  final temp = Directory.systemTemp.createTempSync('war2aty-journey');
  addTearDown(() {
    // Best effort: on Windows a file the app had open (the session image) can
    // still be held when the test ends, and a failed cleanup must not be
    // reported as the test's failure.
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Left for the OS to reap with the rest of the temp directory.
    }
  });

  // A real JPEG-named file for the camera to "take": the online route reads
  // its bytes, and the preview screen points `Image.file` at it.
  final photo = File('${temp.path}/shot.jpg')..writeAsBytesSync(_onePxJpeg);

  final database = memoryDatabase();
  addTearDown(database.close);

  // A *configured* dev environment: `isConfigured` is what makes DI choose the
  // real Edge Function datasources and the real usage repository over the
  // refuse-everything stubs. Nothing talks to this host — `FakeEdgeFunctions`
  // is installed below the Dio that would.
  await configureDependencies(
    const AppEnvironment(
      flavor: Flavor.dev,
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'journey-publishable-key',
    ),
    database: database,
  );
  addTearDown(getIt.reset);

  // Only from here on: `configureDependencies` itself must still fail on a
  // double registration, which this would otherwise hide. Put back
  // afterwards so it cannot leak into another test in the same file.
  getIt.allowReassignment = true;
  addTearDown(() => getIt.allowReassignment = false);

  final paperDeadline = deadline ?? journeyDeadline();
  final backend = FakeEdgeFunctions(
    dailyLimit: dailyLimit,
    usedToday: usedToday,
    onlineOcrEnabled: onlineOcrEnabled,
    analysisEnabled: analysisEnabled,
    analyzeBody: journeyInvoiceBody(deadline: paperDeadline),
  );
  final camera = FakeCameraService(photo: CapturedPhoto(photo.path));
  final picker = FakeImagePickerService(photo: CapturedPhoto(photo.path));
  final permissionService = FakePermissionService(outcome: permissions);
  final connectivityService = FakeConnectivityService(connected: connected);
  final ocrEngine = FakeOcrEngine(text: ocrText);
  final notifications = FakeLocalNotificationsPort();
  final tts = FakeTextToSpeechService();
  addTearDown(tts.dispose);
  final documentImages = FakeDocumentImageStore();
  final sessions = TempAnalysisSessionStorage(temp);
  final cleanup = FakeCaptureFileCleanup();

  getIt
    // Identity: the stub, over fake secure storage — never Supabase (see the
    // library doc).
    ..registerLazySingleton<SecureStorageService>(FakeSecureStorage.new)
    ..registerLazySingleton<AuthRepository>(
      () => StubAuthRepository(getIt(), getIt()),
    )
    // Platform channels.
    ..registerLazySingleton<PermissionService>(() => permissionService)
    ..registerLazySingleton<ConnectivityService>(() => connectivityService)
    ..registerLazySingleton<LocalNotificationsPort>(() => notifications)
    ..registerLazySingleton<TextToSpeechService>(() => tts)
    ..registerLazySingleton<ImagePickerService>(() => picker)
    // The `image` package's three isolate-bound services, and Tesseract.
    ..registerLazySingleton<ImageRotator>(FakeImageRotator.new)
    ..registerLazySingleton<ImageCropper>(FakeImageCropper.new)
    ..registerLazySingleton<ImageQualityService>(
      () => FakeImageQualityService(result: quality),
    )
    ..registerLazySingleton<ImagePreprocessor>(FakeImagePreprocessor.new)
    ..registerLazySingleton<OcrEngine>(() => ocrEngine)
    // Files: the session directory is real (the online route reads from it),
    // the encrypted store and the temp-file sweep are not.
    ..registerLazySingleton<AnalysisSessionStorage>(() => sessions)
    ..registerLazySingleton<CaptureFileCleanup>(() => cleanup)
    ..registerLazySingleton<DocumentImageStore>(() => documentImages)
    // The one dependency DI builds inside a cubit factory rather than
    // registering: `PlatformCameraService` is constructed in place, so the
    // only way past it is to re-wire this one cubit exactly as DI does.
    ..registerFactory<CameraCaptureCubit>(
      () => CameraCaptureCubit(
        preview: const FakeCameraPreview(),
        initializeCamera: InitializeCamera(camera),
        capturePhoto: CapturePhoto(camera),
        setCameraFlash: SetCameraFlash(camera),
        focusCamera: FocusCamera(camera),
        disposeCamera: DisposeCamera(camera),
        cleanupFiles: getIt(),
      ),
    );

  if (analysisConsent != null) {
    await getIt<AnalysisConsentStore>().writeConsent(analysisConsent);
  }
  if (seenOnboarding) {
    await getIt<OnboardingRepository>().markOnboardingSeen();
  }

  // Installed on the app's own client, so the request still goes through
  // every real interceptor on its way here.
  getIt<Dio>().httpClientAdapter = backend;

  await tester.pumpWidget(const WaraqtiApp());
  await tester.pumpAndSettle();

  return AppHarness(
    tester: tester,
    backend: backend,
    camera: camera,
    picker: picker,
    permissions: permissionService,
    connectivity: connectivityService,
    ocrEngine: ocrEngine,
    notifications: notifications,
    tts: tts,
    documentImages: documentImages,
    sessions: sessions,
    database: database,
    photoPath: photo.path,
    deadline: paperDeadline,
  );
}

/// The smallest real JPEG: a 1x1 white pixel, as base64.
///
/// The camera's photo has to be a file that exists and is named `.jpg` — the
/// online request reads its bytes and derives `image/jpeg` from the extension
/// — but nothing in the app decodes it (the quality and rotate services are
/// faked), so one pixel is enough.
final Uint8List _onePxJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkS'
  'Ew8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAAB'
  'AAEBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgED'
  'AwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2Jy'
  'ggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1'
  'dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJ'
  'ytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/ANLPIP/Z',
);
