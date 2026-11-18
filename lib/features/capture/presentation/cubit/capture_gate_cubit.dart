import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/capture_readiness.dart';
import '../../domain/entities/capture_source.dart';
import '../../domain/usecases/check_capture_readiness.dart';
import 'capture_gate_state.dart';

final class CaptureGateCubit extends Cubit<CaptureGateState> {
  CaptureGateCubit({required CheckCaptureReadiness checkCaptureReadiness})
    : _checkCaptureReadiness = checkCaptureReadiness,
      super(const CaptureGateIdle());

  final CheckCaptureReadiness _checkCaptureReadiness;
  bool _busy = false;

  Future<void> check(CaptureSource source) async {
    if (_busy || isClosed) return;
    _busy = true;

    final readiness = await _checkCaptureReadiness();
    _busy = false;
    if (isClosed) return;

    emit(switch (readiness) {
      CaptureReadinessReady() => CaptureGateOpen(source),
      CaptureReadinessOffline() => CaptureGateOffline(source),
      CaptureReadinessServiceOff() => CaptureGateServiceOff(source),
    });
  }
}
