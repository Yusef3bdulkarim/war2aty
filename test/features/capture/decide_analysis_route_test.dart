import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/connectivity/analysis_route.dart';
import 'package:war2aty/core/connectivity/connectivity_service.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';

void main() {
  group('DecideAnalysisRoute', () {
    test('routes online when the OS reports connectivity', () async {
      final decide = DecideAnalysisRoute(_FakeConnectivityService(true));

      expect(await decide(), AnalysisRoute.online);
    });

    test('routes offline when the OS reports no connectivity', () async {
      final decide = DecideAnalysisRoute(_FakeConnectivityService(false));

      expect(await decide(), AnalysisRoute.offline);
    });

    test('routes offline when the connectivity check throws', () async {
      final decide = DecideAnalysisRoute(
        _FakeConnectivityService(false, fails: true),
      );

      expect(await decide(), AnalysisRoute.offline);
    });
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
