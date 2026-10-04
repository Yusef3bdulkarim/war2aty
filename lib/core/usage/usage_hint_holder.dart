import 'package:flutter/foundation.dart';

/// Carries a one-shot "remaining analyses today" count from the analysis
/// result screen to the shell, where it appears as a SnackBar.
///
/// Set by the router when the result route leaves the tree, however it is
/// left (F26-T04); consumed by `ScaffoldWithNavBar` once it is the top route.
/// The holder notifies listeners when a value is stored so the shell can
/// react even if its `initState` ran before the hint was set.
final class UsageHintHolder extends ChangeNotifier {
  int? _remaining;

  /// Stores [remaining] and notifies listeners.
  void set(int remaining) {
    _remaining = remaining;
    notifyListeners();
  }

  /// Drops a stored count without showing it — one left over from an earlier
  /// analysis is stale once a new one starts.
  void clear() => _remaining = null;

  /// Returns and clears the stored count, or `null` when empty.
  ///
  /// Idempotent: the second call always returns `null`.
  int? consume() {
    final r = _remaining;
    _remaining = null;
    return r;
  }
}
