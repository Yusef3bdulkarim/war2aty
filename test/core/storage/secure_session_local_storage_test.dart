import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/storage/secure_session_local_storage.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';

/// F27-T16: the Supabase session goes to secure storage, not `SharedPreferences`.
///
/// The SDK's default store wrote the serialized session — access JWT and
/// long-lived refresh token — in plaintext, while `SecureStorageKeys.session`
/// declared it had to stay encrypted. These tests pin the three things that
/// make the declaration true: the right key, the round trip, and the
/// non-throwing contract that keeps a keystore error from blanking the app's
/// configuration at launch.
void main() {
  group('SecureSessionLocalStorage (F27-T16)', () {
    test('persists the session under the secure-storage session key', () async {
      final storage = _FakeSecureStorage();
      final local = SecureSessionLocalStorage(storage);

      await local.persistSession('{"refresh_token":"secret"}');

      expect(storage.values, {
        SecureStorageKeys.session: '{"refresh_token":"secret"}',
      });
      // The guard that matters: the key the old code promised but never used.
      expect(storage.values.containsKey(SecureStorageKeys.session), isTrue);
    });

    test('reads back what it persisted', () async {
      final storage = _FakeSecureStorage();
      final local = SecureSessionLocalStorage(storage);

      expect(await local.hasAccessToken(), isFalse);
      expect(await local.accessToken(), isNull);

      await local.persistSession('session-json');

      expect(await local.hasAccessToken(), isTrue);
      expect(await local.accessToken(), 'session-json');
    });

    test('removing the session clears it', () async {
      final storage = _FakeSecureStorage();
      final local = SecureSessionLocalStorage(storage);

      await local.persistSession('session-json');
      await local.removePersistedSession();

      expect(await local.hasAccessToken(), isFalse);
      expect(storage.values, isEmpty);
    });

    test('initialize does not touch the store', () async {
      final storage = _FakeSecureStorage();

      await SecureSessionLocalStorage(storage).initialize();

      expect(storage.reads, isEmpty);
      expect(storage.values, isEmpty);
    });

    group('a failing keystore cannot break the launch', () {
      test('a read failure reports "no session" instead of throwing', () async {
        final local = SecureSessionLocalStorage(_FakeSecureStorage(fail: true));

        // Both must stay non-throwing: these run inside Supabase.initialize,
        // whose caller degrades the whole app to "service unavailable" on any
        // throw. Reporting no session instead costs a fresh anonymous sign-in.
        expect(await local.accessToken(), isNull);
        expect(await local.hasAccessToken(), isFalse);
      });

      test('a write failure is swallowed', () async {
        final local = SecureSessionLocalStorage(_FakeSecureStorage(fail: true));

        await expectLater(local.persistSession('x'), completes);
        await expectLater(local.removePersistedSession(), completes);
      });
    });
  });
}

final class _FakeSecureStorage implements SecureStorageService {
  _FakeSecureStorage({this.fail = false});

  final bool fail;
  final Map<String, String> values = {};
  final List<String> reads = [];

  @override
  Future<String?> read(String key) async {
    if (fail) throw Exception('keystore unavailable');
    reads.add(key);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw Exception('keystore unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (fail) throw Exception('keystore unavailable');
    values.remove(key);
  }
}
