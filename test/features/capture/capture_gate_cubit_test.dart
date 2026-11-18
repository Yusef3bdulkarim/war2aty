import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/connectivity/connectivity_service.dart';
import 'package:war2aty/features/capture/domain/entities/capture_source.dart';
import 'package:war2aty/features/capture/domain/usecases/check_capture_readiness.dart';
import 'package:war2aty/features/capture/presentation/cubit/capture_gate_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/capture_gate_state.dart';

import '../../support/fakes.dart';

final class _PausableConnectivity implements ConnectivityService {
  final Completer<bool> _completer = Completer();
  int callCount = 0;

  void complete(bool value) => _completer.complete(value);

  @override
  Future<bool> hasConnectivity() {
    callCount++;
    return _completer.future;
  }
}

CaptureGateCubit _cubitWith({
  bool connected = true,
  bool? explainEnabled = true,
}) => CaptureGateCubit(
  checkCaptureReadiness: CheckCaptureReadiness(
    FakeConnectivityService(connected: connected),
    FakeUsageRepository()..lastKnownExplainEnabled = explainEnabled,
  ),
);

void main() {
  group('CaptureGateCubit', () {
    test('starts idle', () {
      expect(_cubitWith().state, isA<CaptureGateIdle>());
    });

    test(
      'emits open with the camera source when connectivity is up and service is on',
      () async {
        final cubit = _cubitWith();
        await cubit.check(CaptureSource.camera);
        expect(cubit.state, const CaptureGateOpen(CaptureSource.camera));
      },
    );

    test('carries the gallery source through to the open state', () async {
      final cubit = _cubitWith();
      await cubit.check(CaptureSource.gallery);
      expect(cubit.state, const CaptureGateOpen(CaptureSource.gallery));
    });

    test('emits offline when connectivity is down', () async {
      final cubit = _cubitWith(connected: false);
      await cubit.check(CaptureSource.camera);
      expect(cubit.state, isA<CaptureGateOffline>());
    });

    test('emits serviceOff when explain_enabled is known false', () async {
      final cubit = _cubitWith(explainEnabled: false);
      await cubit.check(CaptureSource.camera);
      expect(cubit.state, isA<CaptureGateServiceOff>());
    });

    test(
      'busy guard: a concurrent check is ignored and starts only one readiness call',
      () async {
        final slow = _PausableConnectivity();
        final cubit = CaptureGateCubit(
          checkCaptureReadiness: CheckCaptureReadiness(
            slow,
            FakeUsageRepository()..lastKnownExplainEnabled = true,
          ),
        );

        final first = cubit.check(CaptureSource.camera);
        final second = cubit.check(CaptureSource.gallery);
        slow.complete(true);
        await first;
        await second;

        expect(cubit.state, const CaptureGateOpen(CaptureSource.camera));
        expect(slow.callCount, 1);
      },
    );

    test(
      'no crash and no emit when the cubit is closed before the check completes',
      () async {
        final slow = _PausableConnectivity();
        final cubit = CaptureGateCubit(
          checkCaptureReadiness: CheckCaptureReadiness(
            slow,
            FakeUsageRepository()..lastKnownExplainEnabled = true,
          ),
        );

        final future = cubit.check(CaptureSource.camera);
        await cubit.close();
        slow.complete(true);
        await future;
      },
    );
  });
}
