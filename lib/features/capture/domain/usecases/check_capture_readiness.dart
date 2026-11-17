import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/result/result.dart';
import '../../../../core/usage/usage_repository.dart';
import '../entities/capture_readiness.dart';

final class CheckCaptureReadiness {
  const CheckCaptureReadiness(this._connectivity, this._usageRepository);

  final ConnectivityService _connectivity;
  final UsageRepository _usageRepository;

  Future<CaptureReadiness> call() async {
    if (!await _hasConnectivity()) return const CaptureReadinessOffline();

    final known = _usageRepository.lastKnownExplainEnabled;
    if (known != null) return _readinessFor(explainEnabled: known);

    final result = await _usageRepository.syncUsage();
    return switch (result) {
      Ok(:final value) => _readinessFor(explainEnabled: value.explainEnabled),
      Err() => const CaptureReadinessReady(),
    };
  }

  Future<bool> _hasConnectivity() async {
    try {
      return await _connectivity.hasConnectivity();
    } on Object {
      return false;
    }
  }

  CaptureReadiness _readinessFor({required bool? explainEnabled}) =>
      explainEnabled == false
      ? const CaptureReadinessServiceOff()
      : const CaptureReadinessReady();
}
