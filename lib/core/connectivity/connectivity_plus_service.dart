import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_service.dart';

/// [ConnectivityService] backed by the `connectivity_plus` plugin.
///
/// `checkConnectivity()` reads the OS's current interface list without
/// sending anything on the wire — an interface being up says nothing about
/// whether a given server is reachable (F13 locked decision #11).
final class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> hasConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
