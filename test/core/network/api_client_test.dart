import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/network/api_client.dart';

/// F27-T05: Edge Functions run at the edge region nearest the *caller*, not in
/// the project's region, so without this header a call from Egypt executed in
/// `ap-south-1` while the database sat in `eu-central-1`. The header is what
/// puts the function next to its data, so these tests pin the contract: it is
/// present exactly when a region is configured, and absent otherwise.
void main() {
  group('createApiClient · x-region', () {
    test('sends the configured region', () {
      final dio = createApiClient(
        environment: const AppEnvironment(
          flavor: Flavor.prod,
          supabaseUrl: 'https://prod.example.supabase.co',
          supabaseAnonKey: 'prod-key',
          functionRegion: 'eu-central-1',
        ),
        logger: _SilentLogger(),
        accessToken: () async => null,
        refreshSession: () async => null,
      );

      expect(dio.options.headers['x-region'], 'eu-central-1');
    });

    test('omits the header when no region is configured', () {
      final dio = createApiClient(
        environment: const AppEnvironment(
          flavor: Flavor.dev,
          supabaseUrl: 'http://127.0.0.1:54321',
          supabaseAnonKey: 'local-key',
        ),
        logger: _SilentLogger(),
        accessToken: () async => null,
        refreshSession: () async => null,
      );

      // Not merely empty: an `x-region: ''` would be a header the platform has
      // to interpret, and the local stack has no edge regions at all.
      expect(dio.options.headers.containsKey('x-region'), isFalse);
    });
  });
}

final class _SilentLogger implements AppLogger {
  @override
  void event(LogEvent e) {}

  @override
  void failure(_, {LogStage? stage, String? sessionId}) {}
}
