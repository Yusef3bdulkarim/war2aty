import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/config/local_runtime_config_repository.dart';
import 'package:war2aty/core/config/runtime_config.dart';
import 'package:war2aty/core/config/runtime_config_dto.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late LocalRuntimeConfigRepository repo;

  setUp(() {
    db = memoryDatabase();
    repo = LocalRuntimeConfigRepository(db);
  });
  tearDown(() => db.close());

  group('defaults', () {
    test('match the locked product decisions', () {
      const defaults = RuntimeConfig.defaults;
      expect(defaults.analysisEnabled, isTrue);
      expect(defaults.dailyAnalysisLimit, 3);
      expect(defaults.schemaVersion, '1.0');
      expect(defaults.maintenanceMessage, isNull);
      expect(defaults.analysisTimeout, const Duration(seconds: 30));
    });
  });

  group('load', () {
    test('returns defaults when nothing is cached', () async {
      expect(
        await repo.load(),
        const Ok<RuntimeConfig, AppFailure>(RuntimeConfig.defaults),
      );
    });

    test('returns the cached config when present', () async {
      const custom = RuntimeConfig(
        analysisEnabled: false,
        dailyAnalysisLimit: 5,
        maxOcrCharacters: 999,
        analysisTimeout: Duration(seconds: 12),
        schemaVersion: '2.0',
        minimumAppVersion: '2.1.0',
        maintenanceMessage: 'صيانة',
      );
      await repo.cache(custom);

      expect(await repo.load(), const Ok<RuntimeConfig, AppFailure>(custom));
    });

    test('falls back to defaults on corrupt cached data', () async {
      await db.setSetting('runtime_config', '{not valid json');

      expect(
        await repo.load(),
        const Ok<RuntimeConfig, AppFailure>(RuntimeConfig.defaults),
        reason: 'a bad cache must never block launch',
      );
    });
  });

  group('RuntimeConfigDto', () {
    test('round-trips through JSON without loss', () {
      const original = RuntimeConfig.defaults;

      final json = RuntimeConfigDto.fromEntity(original).toJson();
      final restored = RuntimeConfigDto.fromJson(json).toEntity();

      expect(restored, original);
    });

    test('uses the backend key names', () {
      final json = RuntimeConfigDto.fromEntity(RuntimeConfig.defaults).toJson();

      expect(
        json.keys,
        containsAll(<String>[
          'analysis_enabled',
          'daily_limit',
          'max_ocr_characters',
          'schema_version',
          'minimum_app_version',
        ]),
      );
    });

    test('preserves a null maintenance message', () {
      final json = RuntimeConfigDto.fromEntity(RuntimeConfig.defaults).toJson();
      expect(RuntimeConfigDto.fromJson(json).maintenanceMessage, isNull);
    });
  });
}
