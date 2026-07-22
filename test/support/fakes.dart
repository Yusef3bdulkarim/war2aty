import 'dart:async';

import 'package:drift/native.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/documents/recent_documents_repository.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/locale_store.dart';
import 'package:war2aty/core/logging/log_sink.dart';
import 'package:war2aty/core/reminders/upcoming_reminder.dart';
import 'package:war2aty/core/reminders/upcoming_reminder_repository.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/usage_repository.dart';
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
