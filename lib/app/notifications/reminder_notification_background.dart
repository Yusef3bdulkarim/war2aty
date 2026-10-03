import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;

import '../../core/database/app_database.dart';
import '../../core/error/app_failure.dart';
import '../../core/localization/ar_strings.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/usecases/get_saved_locale.dart';
import '../../core/reminders/drift_reminders_repository.dart';
import '../../core/reminders/flutter_local_notifications_port.dart';
import '../../core/reminders/flutter_local_notifications_reminder_scheduler.dart';
import '../../core/reminders/local_notifications_port.dart';
import '../../core/reminders/notification_privacy_store.dart';
import '../../core/reminders/reminder_notification_response.dart';
import '../../core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import '../../core/reminders/usecases/handle_reminder_notification_action.dart';
import '../../core/result/result.dart';

/// Where a pressed «تم» / «أجّل ساعة» runs (F25-T05): a background engine
/// the platform starts for it, with or without the app running.
///
/// That engine runs none of `configureDependencies` — no Supabase, no
/// `getIt`, no launch sequence — so this builds the few objects the action
/// needs itself ([runReminderNotificationAction]) and closes the database
/// when done. It does not re-initialize the plugin the app already set up;
/// scheduling only needs the timezone data.
///
/// Top-level and `vm:entry-point`: the platform calls it by handle, and
/// tree shaking must not drop it.
@pragma('vm:entry-point')
Future<void> onReminderNotificationBackgroundResponse(
  fln.NotificationResponse response,
) async {
  final chosen = reminderNotificationResponseFromPlugin(response);
  if (chosen is! ReminderNotificationActionChosen) return;

  initializeReminderTimeZones();
  final database = AppDatabase();
  try {
    await runReminderNotificationAction(
      chosen,
      database: database,
      notifications: FlutterLocalNotificationsPort(
        fln.FlutterLocalNotificationsPlugin(),
        // Arabic, unconditionally — the same channel name the app registers
        // (see `FlutterLocalNotificationsPort`'s own doc comment).
        const ArStrings().reminderNotificationChannelName,
      ),
    );
  } on Object {
    // A background engine has no screen to report to, and nothing about
    // the reminder may reach a log (§7). Whatever did not land is redone by
    // the next launch's reconcile (F09-T13).
  } finally {
    await database.close();
  }
}

/// The background engine's own composition of the action — the same
/// repository, scheduler and use case the app builds through `getIt`,
/// wired by hand over [database] and [notifications].
Future<Result<void, AppFailure>> runReminderNotificationAction(
  ReminderNotificationActionChosen chosen, {
  required AppDatabase database,
  required LocalNotificationsPort notifications,
  DateTime Function()? now,
}) {
  final repository = DriftRemindersRepository(database.remindersDao);
  final scheduler = LocalNotificationsReminderScheduler(
    notifications,
    repository,
    GetSavedLocale(DriftLocaleStore(database)),
    GetHideSensitiveNotificationDetails(
      DriftNotificationPrivacyStore(database),
    ),
  );
  return HandleReminderNotificationAction(repository, scheduler, now: now)(
    chosen.reminderId,
    chosen.action,
  );
}
