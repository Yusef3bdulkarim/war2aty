import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/env/app_environment.dart';

void main() {
  group('local stack URL', () {
    test('an Android emulator reaches the host through 10.0.2.2', () {
      // 127.0.0.1 from inside the emulator is the *emulator*, not the dev
      // machine. Getting this backwards produces a connection-refused that
      // looks exactly like a stack which is not running.
      expect(AppEnvironment.localStackUrl(true), 'http://10.0.2.2:54321');
    });

    test('an iOS simulator uses the host loopback directly', () {
      expect(AppEnvironment.localStackUrl(false), 'http://127.0.0.1:54321');
    });
  });

  group('AppEnvironment.dev', () {
    test('points at the local stack and is configured', () {
      final env = AppEnvironment.dev(isAndroid: true);

      expect(env.flavor, Flavor.dev);
      expect(env.supabaseUrl, 'http://10.0.2.2:54321');
      expect(env.supabaseAnonKey, isNotEmpty);
      expect(env.isConfigured, isTrue);
    });

    test('exposes the functions base URL the datasources call', () {
      final env = AppEnvironment.dev(isAndroid: false);

      expect(env.functionsBaseUrl, 'http://127.0.0.1:54321/functions/v1');
    });

    test('carries the app version through for the §29 version gate', () {
      final env = AppEnvironment.dev(isAndroid: false, appVersion: '1.4.2');

      expect(env.appVersion, '1.4.2');
    });
  });

  group('AppEnvironment.prod', () {
    test('reports itself unconfigured without its dart-defines', () {
      // Tests run without --dart-define, which is exactly the forgotten-build
      // case. DI must then refuse analyses rather than point at a placeholder.
      final env = AppEnvironment.prod();

      expect(env.isConfigured, isFalse);
      expect(env.isDev, isFalse);
    });
  });

  group('isConfigured', () {
    test('needs both a URL and a key', () {
      const noKey = AppEnvironment(
        flavor: Flavor.prod,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
      );
      const noUrl = AppEnvironment(
        flavor: Flavor.prod,
        supabaseUrl: '',
        supabaseAnonKey: 'key',
      );

      expect(noKey.isConfigured, isFalse);
      expect(noUrl.isConfigured, isFalse);
    });
  });
}
