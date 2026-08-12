import '../../../../core/connectivity/analysis_route.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/result/result.dart';
import '../../../../core/usage/usage_repository.dart';

/// Picks the analysis pipeline before capture processing starts.
///
/// Called once per capture, ahead of [PerspectiveCorrector]/`OcrEngine` —
/// never re-checked mid-flow, and never used to decide whether to fall back
/// once [AnalysisRoute.online] has been chosen (F13 locked decision #2).
///
/// Connectivity alone is not enough to route online: the backend's
/// Azure/Google image pipeline is dark-launched behind its own
/// `azureOcrEnabled` flag (`RuntimeConfig`), off by default. A build that
/// only checked connectivity would send every connected user's capture down
/// a route the server rejects outright — and since locked decision #2
/// forbids falling back once online is chosen, that is a dead end, not a
/// harmless no-op. [_usageRepository] carries the same flag the Home screen
/// already fetches (`get-usage`'s `azure_ocr_enabled`), so this checks it
/// too, fetched fresh — a cached-only reading always reads `false` (see
/// `DailyUsage.azureOcrEnabled`), and any failure to read it fails closed to
/// offline, the always-available route.
final class DecideAnalysisRoute {
  const DecideAnalysisRoute(this._connectivity, this._usageRepository);

  final ConnectivityService _connectivity;
  final UsageRepository _usageRepository;

  Future<AnalysisRoute> call() async {
    if (!await _hasConnectivity()) return AnalysisRoute.offline;
    return await _isOnlinePipelineLive()
        ? AnalysisRoute.online
        : AnalysisRoute.offline;
  }

  // A plugin-channel error is not itself a decision — it just means the OS
  // couldn't answer, so the safe read is "no connectivity" (route offline),
  // never an exception escaping into the cubit (no-throw use-case contract).
  Future<bool> _hasConnectivity() async {
    try {
      return await _connectivity.hasConnectivity();
    } on Object {
      return false;
    }
  }

  // A fresh fetch, not the cache: this decision needs the live server state,
  // and a stale cached "true" is the dangerous direction to be wrong in.
  // Any failure — no result yet, a network hiccup despite the connectivity
  // check above, an unreadable response — reads as "not live" rather than
  // escaping as an exception (same no-throw contract as connectivity above).
  Future<bool> _isOnlinePipelineLive() async {
    final result = await _usageRepository.syncUsage();
    return switch (result) {
      Ok(:final value) => value.azureOcrEnabled,
      Err() => false,
    };
  }
}
