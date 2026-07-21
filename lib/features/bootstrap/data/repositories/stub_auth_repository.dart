import 'dart:convert';

import '../../../../core/error/app_failure.dart';
import '../../../../core/identity/installation_id_provider.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/app_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_session_dto.dart';

/// Offline stand-in for real Supabase Anonymous Auth (arrives at M4).
///
/// Mints a local session derived from the installation id and persists it in
/// secure storage, so the rest of the launch flow can be built and tested
/// end-to-end without a backend. It makes no network calls and contains no
/// secrets — [_stubToken] is an obvious placeholder, never a real credential.
final class StubAuthRepository implements AuthRepository {
  StubAuthRepository(
    this._installationIds,
    this._storage, {
    DateTime Function()? clock,
    Duration sessionDuration = const Duration(hours: 1),
  }) : _now = clock ?? DateTime.now,
       _sessionDuration = sessionDuration;

  static const String _stubToken = 'stub-access-token';

  final InstallationIdProvider _installationIds;
  final SecureStorageService _storage;
  final DateTime Function() _now;
  final Duration _sessionDuration;

  @override
  Future<Result<AppSession, AppFailure>> signInAnonymously() => _mintSession();

  @override
  Future<Result<AppSession, AppFailure>> refreshSession() => _mintSession();

  @override
  Future<Result<AppSession?, AppFailure>> restoreSession() async {
    try {
      final raw = await _storage.read(SecureStorageKeys.session);
      if (raw == null || raw.isEmpty) return const Ok(null);

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return Ok(AppSessionDto.fromJson(decoded).toEntity());
    } on Object {
      // A corrupt/unreadable session is treated as "no session" rather than a
      // hard failure — the caller simply signs in again.
      return const Ok(null);
    }
  }

  /// Creates a new session from the installation id and persists it.
  Future<Result<AppSession, AppFailure>> _mintSession() async {
    final installationId = await _installationIds.getOrCreate();

    // Without an installation id no session can be minted — failure propagates.
    if (installationId case Err(:final failure)) return Err(failure);

    final session = AppSession(
      userId: 'anon-${installationId.valueOrNull}',
      accessToken: _stubToken,
      expiresAt: _now().add(_sessionDuration),
    );

    try {
      await _storage.write(
        SecureStorageKeys.session,
        jsonEncode(AppSessionDto.fromEntity(session).toJson()),
      );
    } on Object {
      return const Err(FileStorageFailure());
    }

    return Ok(session);
  }
}
