import '../localization/app_strings.dart';

/// The buttons on every reminder notification (F25-T02).
///
/// [id] is what the OS hands back when the button is pressed — the same
/// string on Android (per notification) and iOS (per category).
enum ReminderNotificationAction {
  /// «تم» — marks the reminder done.
  complete('complete'),

  /// «أجّل ساعة» — fires it again an hour from now.
  snooze('snooze');

  const ReminderNotificationAction(this.id);

  final String id;
}

/// The buttons' labels, already in the user's language — the port has no
/// strings of its own.
final class ReminderNotificationActionLabels {
  const ReminderNotificationActionLabels({
    required this.complete,
    required this.snooze,
  });

  factory ReminderNotificationActionLabels.of(AppStrings s) =>
      ReminderNotificationActionLabels(
        complete: s.reminderNotificationActionComplete,
        snooze: s.reminderNotificationActionSnooze,
      );

  final String complete;
  final String snooze;

  String labelOf(ReminderNotificationAction action) => switch (action) {
    ReminderNotificationAction.complete => complete,
    ReminderNotificationAction.snooze => snooze,
  };
}

/// What the user did with a reminder notification, with the plugin's own
/// response type left behind at the port (CLAUDE.md §B9).
sealed class ReminderNotificationResponse {
  const ReminderNotificationResponse(this.reminderId);

  final String reminderId;
}

/// Tapped the notification itself — open that reminder.
final class ReminderNotificationOpened extends ReminderNotificationResponse {
  const ReminderNotificationOpened(super.reminderId);

  @override
  bool operator ==(Object other) =>
      other is ReminderNotificationOpened && other.reminderId == reminderId;

  @override
  int get hashCode => reminderId.hashCode;

  @override
  String toString() => 'ReminderNotificationOpened($reminderId)';
}

/// Pressed one of the notification's buttons.
final class ReminderNotificationActionChosen
    extends ReminderNotificationResponse {
  const ReminderNotificationActionChosen(super.reminderId, this.action);

  final ReminderNotificationAction action;

  @override
  bool operator ==(Object other) =>
      other is ReminderNotificationActionChosen &&
      other.reminderId == reminderId &&
      other.action == action;

  @override
  int get hashCode => Object.hash(reminderId, action);

  @override
  String toString() =>
      'ReminderNotificationActionChosen($reminderId, ${action.name})';
}

/// Reads what the OS handed back: [payload] is the reminder id every
/// reminder notification is scheduled with, [actionId] the pressed button's
/// [ReminderNotificationAction.id] — `null` or empty for a tap on the
/// notification itself.
///
/// `null` when [payload] carries no reminder id (a notification scheduled
/// before F25 had none), or [actionId] names a button this version does not
/// know — nothing to act on, rather than a guess.
ReminderNotificationResponse? reminderNotificationResponseOf({
  required String? payload,
  required String? actionId,
}) {
  if (payload == null || payload.isEmpty) return null;
  if (actionId == null || actionId.isEmpty) {
    return ReminderNotificationOpened(payload);
  }
  for (final action in ReminderNotificationAction.values) {
    if (action.id == actionId) {
      return ReminderNotificationActionChosen(payload, action);
    }
  }
  return null;
}
