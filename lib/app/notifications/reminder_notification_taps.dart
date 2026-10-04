import 'package:flutter/foundation.dart';

/// The reminder a notification tap asked to open, held until the router is
/// up to show it (F25-T04).
///
/// A tap can arrive before there is anything to navigate with: the one that
/// launched the app is read during the splash, long before the router
/// exists. Holding it here and letting `ReminderNotificationOpener` take it
/// once the router has built covers that and the warm case the same way.
final class ReminderNotificationTaps extends ChangeNotifier {
  String? _pending;

  /// Asks for [reminderId]'s details. A newer tap replaces one not yet
  /// shown — the user wants the reminder they tapped last.
  void open(String reminderId) {
    _pending = reminderId;
    notifyListeners();
  }

  /// The reminder to open, at most once.
  String? take() {
    final id = _pending;
    _pending = null;
    return id;
  }
}
