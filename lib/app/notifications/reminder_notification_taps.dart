import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/reminders/reminder_notification_response.dart';
import '../../core/reminders/usecases/handle_reminder_notification_action.dart';

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

/// Routes what the user did with a reminder notification, in the app's own
/// isolate: a tap opens the reminder; a button press (which normally runs
/// in the background engine instead, F25-T05) is handled here too, so it is
/// never dropped if a platform delivers it to the app.
void dispatchReminderNotificationResponse(
  ReminderNotificationResponse response, {
  required ReminderNotificationTaps taps,
  required HandleReminderNotificationAction handleAction,
}) {
  switch (response) {
    case ReminderNotificationOpened(:final reminderId):
      taps.open(reminderId);
    case ReminderNotificationActionChosen(:final reminderId, :final action):
      unawaited(handleAction(reminderId, action));
  }
}
