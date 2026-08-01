import '../../../../core/connectivity/analysis_route.dart';
import '../../../../core/connectivity/connectivity_service.dart';

/// Picks the analysis pipeline before capture processing starts.
///
/// Called once per capture, ahead of [PerspectiveCorrector]/`OcrEngine` —
/// never re-checked mid-flow, and never used to decide whether to fall back
/// once [AnalysisRoute.online] has been chosen (F13 locked decision #2).
final class DecideAnalysisRoute {
  const DecideAnalysisRoute(this._connectivity);

  final ConnectivityService _connectivity;

  Future<AnalysisRoute> call() async {
    return await _hasConnectivity()
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
}
