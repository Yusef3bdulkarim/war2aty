import 'dart:convert';

import '../database/app_database.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import 'runtime_config.dart';
import 'runtime_config_dto.dart';
import 'runtime_config_repository.dart';

/// Reads the config cached in `app_settings`, falling back to
/// [RuntimeConfig.defaults].
///
/// Config is never allowed to block launch: a missing, unreadable, or corrupt
/// cache simply yields the defaults. Once the backend exists (M4) a remote
/// fetch will populate the cache via [cache].
final class LocalRuntimeConfigRepository implements RuntimeConfigRepository {
  const LocalRuntimeConfigRepository(this._db);

  static const String _key = 'runtime_config';

  final AppDatabase _db;

  @override
  Future<Result<RuntimeConfig, AppFailure>> load() async {
    try {
      final raw = await _db.getSetting(_key);
      if (raw == null || raw.isEmpty) return const Ok(RuntimeConfig.defaults);

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return Ok(RuntimeConfigDto.fromJson(decoded).toEntity());
    } on Object {
      // Unreadable cache is not a launch failure — run on defaults.
      return const Ok(RuntimeConfig.defaults);
    }
  }

  @override
  Future<Result<void, AppFailure>> cache(RuntimeConfig config) async {
    try {
      await _db.setSetting(
        _key,
        jsonEncode(RuntimeConfigDto.fromEntity(config).toJson()),
      );
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }
}
