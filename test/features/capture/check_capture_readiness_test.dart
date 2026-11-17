import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/capture_readiness.dart';
import 'package:war2aty/features/capture/domain/usecases/check_capture_readiness.dart';

import '../../support/fakes.dart';

void main() {
  group('CheckCaptureReadiness', () {
    test(
      'reads offline when the OS reports no connectivity, without syncing an unknown flag',
      () async {
        final usage = FakeUsageRepository();
        final check = CheckCaptureReadiness(
          FakeConnectivityService(connected: false),
          usage,
        );

        expect(await check(), isA<CaptureReadinessOffline>());
        expect(usage.syncCallCount, 0);
      },
    );

    test(
      'reads offline when the OS reports no connectivity even with the service known off',
      () async {
        final usage = FakeUsageRepository()..lastKnownExplainEnabled = false;
        final check = CheckCaptureReadiness(
          FakeConnectivityService(connected: false),
          usage,
        );

        expect(await check(), isA<CaptureReadinessOffline>());
        expect(usage.syncCallCount, 0);
      },
    );

    test(
      'reads offline when the connectivity check throws, without syncing',
      () async {
        final usage = FakeUsageRepository();
        final check = CheckCaptureReadiness(
          FakeConnectivityService(fails: true),
          usage,
        );

        expect(await check(), isA<CaptureReadinessOffline>());
        expect(usage.syncCallCount, 0);
      },
    );

    test(
      'reads serviceOff when the service is known to be off, without syncing',
      () async {
        final usage = FakeUsageRepository()..lastKnownExplainEnabled = false;
        final check = CheckCaptureReadiness(FakeConnectivityService(), usage);

        expect(await check(), isA<CaptureReadinessServiceOff>());
        expect(usage.syncCallCount, 0);
      },
    );

    test(
      'reads ready when the service is known to be on, without syncing',
      () async {
        final usage = FakeUsageRepository()..lastKnownExplainEnabled = true;
        final check = CheckCaptureReadiness(FakeConnectivityService(), usage);

        expect(await check(), isA<CaptureReadinessReady>());
        expect(usage.syncCallCount, 0);
      },
    );

    test(
      'syncs once when unknown, then reads serviceOff from the fresh answer',
      () async {
        final usage = FakeUsageRepository(
          seed: usageWith(limit: 3, remaining: 3, explainEnabled: false),
        );
        final check = CheckCaptureReadiness(FakeConnectivityService(), usage);

        expect(await check(), isA<CaptureReadinessServiceOff>());
        expect(usage.syncCallCount, 1);
      },
    );

    test(
      'syncs once when unknown, then reads ready from a true fresh answer',
      () async {
        final usage = FakeUsageRepository(
          seed: usageWith(limit: 3, remaining: 3, explainEnabled: true),
        );
        final check = CheckCaptureReadiness(FakeConnectivityService(), usage);

        expect(await check(), isA<CaptureReadinessReady>());
        expect(usage.syncCallCount, 1);
      },
    );

    test(
      'syncs once when unknown, then reads ready from a still-unknown fresh answer',
      () async {
        final usage = FakeUsageRepository(
          seed: usageWith(limit: 3, remaining: 3),
        );
        final check = CheckCaptureReadiness(FakeConnectivityService(), usage);

        expect(await check(), isA<CaptureReadinessReady>());
        expect(usage.syncCallCount, 1);
      },
    );

    test('reads ready when unknown and the fresh sync itself fails', () async {
      final usage = FakeUsageRepository();
      final check = CheckCaptureReadiness(FakeConnectivityService(), usage);

      expect(await check(), isA<CaptureReadinessReady>());
      expect(usage.syncCallCount, 1);
    });
  });
}
