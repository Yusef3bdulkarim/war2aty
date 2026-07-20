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
  });
}
