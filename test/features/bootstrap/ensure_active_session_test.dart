import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/bootstrap/domain/entities/app_session.dart';
import 'package:war2aty/features/bootstrap/domain/repositories/auth_repository.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/ensure_active_session.dart';

/// Scriptable auth repository that records which methods were called.
final class _ScriptedAuth implements AuthRepository {
  _ScriptedAuth({
    this.restored = const Ok<AppSession?, AppFailure>(null),
    AppSession? minted,
  }) : _minted = minted;

  final Result<AppSession?, AppFailure> restored;
  final AppSession? _minted;

  final List<String> calls = [];

  @override
  Future<Result<AppSession?, AppFailure>> restoreSession() async {
    calls.add('restore');
    return restored;
  }

  @override
  Future<Result<AppSession, AppFailure>> signInAnonymously() async {
    calls.add('signIn');
    return Ok(_minted!);
  }

  @override
  Future<Result<AppSession, AppFailure>> refreshSession() async {
    calls.add('refresh');
    return Ok(_minted!);
  }
}

void main() {
  final now = DateTime.utc(2026, 7, 21, 12);

  AppSession sessionExpiringAt(DateTime at) =>
      AppSession(userId: 'u', accessToken: 't', expiresAt: at);

  test('signs in when there is no stored session', () async {
    final minted = sessionExpiringAt(now.add(const Duration(hours: 1)));
    final auth = _ScriptedAuth(minted: minted);

    final result = await EnsureActiveSession(auth, clock: () => now)();

    expect(result, Ok<AppSession, AppFailure>(minted));
    expect(auth.calls, ['restore', 'signIn']);
  });

  test('reuses a restored session that is still valid', () async {
    final valid = sessionExpiringAt(now.add(const Duration(hours: 1)));
    final auth = _ScriptedAuth(restored: Ok<AppSession?, AppFailure>(valid));

    final result = await EnsureActiveSession(auth, clock: () => now)();

    expect(result, Ok<AppSession, AppFailure>(valid));
    expect(auth.calls, ['restore'], reason: 'must not hit the network again');
  });

  test('refreshes when the restored session has expired', () async {
    final expired = sessionExpiringAt(now.subtract(const Duration(minutes: 1)));
    final fresh = sessionExpiringAt(now.add(const Duration(hours: 1)));
    final auth = _ScriptedAuth(
      restored: Ok<AppSession?, AppFailure>(expired),
      minted: fresh,
    );

    final result = await EnsureActiveSession(auth, clock: () => now)();

    expect(result, Ok<AppSession, AppFailure>(fresh));
    expect(auth.calls, ['restore', 'refresh']);
  });

  test('propagates a restore failure without signing in', () async {
    final auth = _ScriptedAuth(
      restored: const Err<AppSession?, AppFailure>(FileStorageFailure()),
    );

    final result = await EnsureActiveSession(auth, clock: () => now)();

    expect(result, const Err<AppSession, AppFailure>(FileStorageFailure()));
    expect(auth.calls, ['restore']);
  });
}
