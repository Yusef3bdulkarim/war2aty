/// Platform port for the OS-reported network connectivity state.
///
/// A proactive, local read only (F13 locked decision #11) — it never makes a
/// network call and is never a guarantee that a server is actually
/// reachable, only a signal for which pipeline to start with.
abstract interface class ConnectivityService {
  /// Whether the OS currently reports an active network interface.
  Future<bool> hasConnectivity();
}
