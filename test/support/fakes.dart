import 'package:drift/native.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/localization/locale_store.dart';
import 'package:war2aty/core/logging/log_sink.dart';

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

/// Captures written log fields for assertions.
final class FakeLogSink implements LogSink {
  final List<Map<String, Object>> writes = [];

  @override
  void write(Map<String, Object> fields) => writes.add(fields);
}
