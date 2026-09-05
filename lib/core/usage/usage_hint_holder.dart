import 'package:flutter/foundation.dart';

/// Carries a one-shot "remaining analyses today" count from the analysis
/// result screen to the shell, where it appears as a SnackBar.
///
/// Set by the router before navigating away from the result screen; consumed
/// by `ScaffoldWithNavBar` on its first frame.  The holder notifies listeners
/// when a value is stored so the shell can react even if its `initState` ran
/// before the hint was set.
final class UsageHintHolder extends ChangeNotifier {
  int? _remaining;

  /// Stores [remaining] and notifies listeners.
  void set(int remaining) {
    _remaining = remaining;
    notifyListeners();
  }

  /// Returns and clears the stored count, or `null` when empty.
  ///
  /// Idempotent: the second call always returns `null`.
  int? consume() {
    final r = _remaining;
    _remaining = null;
    return r;
  }
}
