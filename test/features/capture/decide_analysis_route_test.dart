import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/connectivity/analysis_route.dart';
import 'package:war2aty/core/connectivity/connectivity_service.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';

import '../../support/fakes.dart';

void main() {
  group('DecideAnalysisRoute', () {
    test(
      'routes online when connected and the online pipeline is live',
      () async {
        final usage = FakeUsageRepository(
          seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
        );
        final decide = DecideAnalysisRoute(
          _FakeConnectivityService(true),
          usage,
        );

        expect(await decide(), AnalysisRoute.online);
      },
    );

    test('routes offline when the OS reports no connectivity', () async {
      // Never even asked: azureOcrEnabled is irrelevant with no connectivity.
      final usage = FakeUsageRepository(
        seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
      );
      final decide = DecideAnalysisRoute(
        _FakeConnectivityService(false),
        usage,
      );

      expect(await decide(), AnalysisRoute.offline);
    });

    test('routes offline when the connectivity check throws', () async {
      final usage = FakeUsageRepository(
        seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
      );
      final decide = DecideAnalysisRoute(
        _FakeConnectivityService(false, fails: true),
        usage,
      );

      expect(await decide(), AnalysisRoute.offline);
    });

    // The critical regression this class exists to prevent: connectivity
    // alone must never be enough to route online, since the server rejects
    // an image request outright while azureOcrEnabled is off (its default),
    // and locked decision #2 forbids falling back once online is chosen.
    test(
      'routes offline when connected but the online pipeline is not live',
      () async {
        final usage = FakeUsageRepository(
          seed: usageWith(limit: 3, remaining: 3),
        );
        final decide = DecideAnalysisRoute(
          _FakeConnectivityService(true),
          usage,
        );

        expect(await decide(), AnalysisRoute.offline);
      },
    );

    test(
      'routes offline when connected but the live flag cannot be read',
      () async {
        final usage = FakeUsageRepository()..emitFailure();
        final decide = DecideAnalysisRoute(
          _FakeConnectivityService(true),
          usage,
        );

        expect(await decide(), AnalysisRoute.offline);
      },
    );

    test(
      'routes offline when connected but nothing has ever been synced',
      () async {
        final decide = DecideAnalysisRoute(
          _FakeConnectivityService(true),
          FakeUsageRepository(),
        );

        expect(await decide(), AnalysisRoute.offline);
      },
    );
  });
}

final class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this._connected, {this.fails = false});

  final bool _connected;
  final bool fails;

  @override
  Future<bool> hasConnectivity() async {
    if (fails) throw StateError('platform channel unavailable');
    return _connected;
  }
}
