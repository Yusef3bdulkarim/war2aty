import 'package:uuid/uuid.dart';

import '../error/app_failure.dart';
import '../result/result.dart';
import '../storage/secure_storage_service.dart';

/// Generates a fresh identifier. Injected so tests stay deterministic.
typedef IdGenerator = String Function();

/// Supplies the stable, per-installation identifier.
///
/// The id is a UUID v4 created **once** on first launch and kept in secure
/// storage; every later launch returns the same value. It identifies the
/// install, not the person — it is never derived from device identifiers
/// (privacy §50).
abstract interface class InstallationIdProvider {
  Future<Result<String, AppFailure>> getOrCreate();
}

/// [InstallationIdProvider] backed by [SecureStorageService].
final class SecureInstallationIdProvider implements InstallationIdProvider {
  SecureInstallationIdProvider(this._storage, {IdGenerator? generator})
    : _generate = generator ?? (() => const Uuid().v4());

  final SecureStorageService _storage;
  final IdGenerator _generate;

  @override
  Future<Result<String, AppFailure>> getOrCreate() async {
    try {
      final existing = await _storage.read(SecureStorageKeys.installationId);
      if (existing != null && existing.isNotEmpty) {
        return Ok(existing);
      }

      final created = _generate();
      await _storage.write(SecureStorageKeys.installationId, created);
      return Ok(created);
    } on Object {
      // Data-layer boundary: exceptions never escape upward, they become a
      // classified failure (CLAUDE.md §5).
      return const Err(FileStorageFailure());
    }
  }
}
