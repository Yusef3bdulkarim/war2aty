import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/identity/installation_id_provider.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';
import 'package:war2aty/features/bootstrap/data/repositories/stub_auth_repository.dart';
import 'package:war2aty/features/bootstrap/domain/entities/app_session.dart';

import '../../support/fakes.dart';

/// Installation id provider that always fails.
final class _FailingInstallationIds implements InstallationIdProvider {
  @override
  Future<Result<String, AppFailure>> getOrCreate() async =>
      const Err(FileStorageFailure());
}

void main() {
  final fixedNow = DateTime.utc(2026, 7, 21, 12);

  StubAuthRepository buildRepo(FakeSecureStorage storage, {DateTime? now}) {
    return StubAuthRepository(
      SecureInstallationIdProvider(storage, generator: () => 'install-1'),
      storage,
      clock: () => now ?? fixedNow,
    );
  }

  group('signInAnonymously', () {
    test('mints a session derived from the installation id', () async {
      final result = await buildRepo(FakeSecureStorage()).signInAnonymously();

      expect(
        result,
        Ok<AppSession, AppFailure>(
          AppSession(
            userId: 'anon-install-1',
            accessToken: 'stub-access-token',
            expiresAt: fixedNow.add(const Duration(hours: 1)),
          ),
        ),
      );
    });

    test('persists the session so it survives a relaunch', () async {
      final storage = FakeSecureStorage();
      await buildRepo(storage).signInAnonymously();

      final raw = storage.contents[SecureStorageKeys.session];
      expect(raw, isNotNull);
      expect(
        (jsonDecode(raw!) as Map<String, dynamic>)['userId'],
        'anon-install-1',
      );
    });

    test('propagates failure when no installation id can be made', () async {
      final repo = StubAuthRepository(
        _FailingInstallationIds(),
        FakeSecureStorage(),
      );

      expect(
        await repo.signInAnonymously(),
        const Err<AppSession, AppFailure>(FileStorageFailure()),
      );
    });
  });

  group('restoreSession', () {
    test('returns null when nothing was ever saved', () async {
      expect(
        await buildRepo(FakeSecureStorage()).restoreSession(),
        const Ok<AppSession?, AppFailure>(null),
      );
    });

    test('restores a previously saved session', () async {
      final storage = FakeSecureStorage();
      final signedIn = await buildRepo(storage).signInAnonymously();

      // A fresh repository instance simulates the next app launch.
      final restored = await buildRepo(storage).restoreSession();

      expect(restored.valueOrNull, signedIn.valueOrNull);
    });

    test('treats corrupt stored data as "no session"', () async {
      final storage = FakeSecureStorage({
        SecureStorageKeys.session: 'not-json-at-all',
      });

      expect(
        await buildRepo(storage).restoreSession(),
        const Ok<AppSession?, AppFailure>(null),
      );
    });
  });

  group('refreshSession', () {
    test(
      'issues a session with a later expiry and overwrites storage',
      () async {
        final storage = FakeSecureStorage();
        final first = await buildRepo(storage).signInAnonymously();

        final later = fixedNow.add(const Duration(hours: 5));
        final refreshed = await buildRepo(storage, now: later).refreshSession();

        expect(
          refreshed.valueOrNull!.expiresAt.isAfter(
            first.valueOrNull!.expiresAt,
          ),
          isTrue,
        );
        // Identity is unchanged across a refresh.
        expect(refreshed.valueOrNull!.userId, first.valueOrNull!.userId);
      },
    );
  });

  group('AppSession', () {
    test('isExpired is false before expiry, true at/after it', () {
      final session = AppSession(
        userId: 'u',
        accessToken: 't',
        expiresAt: fixedNow,
      );

      expect(
        session.isExpired(fixedNow.subtract(const Duration(minutes: 1))),
        isFalse,
      );
      expect(session.isExpired(fixedNow), isTrue);
      expect(
        session.isExpired(fixedNow.add(const Duration(minutes: 1))),
        isTrue,
      );
    });

    test('toString never exposes the access token', () {
      final session = AppSession(
        userId: 'u',
        accessToken: 'super-secret',
        expiresAt: fixedNow,
      );

      expect(session.toString(), isNot(contains('super-secret')));
    });
  });
}
