import '../localization/app_strings.dart';
import 'reminder.dart';

/// What an OS notification for [reminder] should say.
final class ReminderNotificationContent {
  const ReminderNotificationContent({required this.title, this.body});

  final String title;
  final String? body;
}

/// Builds the notification text for [reminder] (F09-T10).
///
/// [hideSensitiveDetails] is the setting's own current value (F09-T14,
/// default on) — this function does not read it itself, so it stays a pure
/// function of its arguments and needs nothing beyond [strings] to be
/// unit-tested. Hidden shows only generic copy, never the reminder's real
/// title or note: someone glancing at a lock screen should not learn what
/// the reminder is about, or for how much.
ReminderNotificationContent reminderNotificationContent(
  Reminder reminder,
  AppStrings strings, {
  required bool hideSensitiveDetails,
}) {
  if (hideSensitiveDetails) {
    return ReminderNotificationContent(
      title: strings.reminderNotificationGenericTitle,
    );
  }
  return ReminderNotificationContent(
    title: reminder.title,
    body: reminder.description,
  );
}
