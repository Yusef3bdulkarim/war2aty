import 'package:drift/native.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/localization/locale_store.dart';
import 'package:war2aty/core/logging/log_sink.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';

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
