import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/env/app_environment.dart';

void main() {
  group('AppEnvironment', () {
    test('dev flavor exposes name and isDev', () {
      const env = AppEnvironment(
        flavor: Flavor.dev,
        supabaseUrl: 'https://dev.example.supabase.co',
        supabaseAnonKey: 'dev-key',
      );

      expect(env.name, 'dev');
      expect(env.isDev, isTrue);
    });

    test('prod flavor exposes name and isDev', () {
      const env = AppEnvironment(
        flavor: Flavor.prod,
        supabaseUrl: 'https://prod.example.supabase.co',
        supabaseAnonKey: 'prod-key',
      );

      expect(env.name, 'prod');
      expect(env.isDev, isFalse);
    });

    test('leaves the function region unpinned unless one is given', () {
      const env = AppEnvironment(
        flavor: Flavor.prod,
        supabaseUrl: 'https://prod.example.supabase.co',
        supabaseAnonKey: 'prod-key',
      );

      // Empty, not null: an absent dart-define reads as '', and the client
      // omits the header on empty rather than sending a meaningless region.
      expect(env.functionRegion, isEmpty);
    });

    test('carries the function region it was built with', () {
      const env = AppEnvironment(
        flavor: Flavor.prod,
        supabaseUrl: 'https://prod.example.supabase.co',
        supabaseAnonKey: 'prod-key',
        functionRegion: 'eu-central-1',
      );

      expect(env.functionRegion, 'eu-central-1');
    });
  });
}
