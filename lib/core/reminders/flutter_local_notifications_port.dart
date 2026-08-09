import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notifications_port.dart';

/// The Android channel every reminder notification is posted under. One
/// channel is enough — reminders do not have sub-categories the user would
/// want to mute independently.
const String reminderNotificationChannelId = 'reminders';

/// [LocalNotificationsPort] on top of `flutter_local_notifications` and the
/// `timezone` package (F09-T10) — the only file in the app allowed to import
/// either, matching how `PermissionHandlerService` is the only file that
/// imports `permission_handler`.
///
/// Android alarms are scheduled [fln.AndroidScheduleMode.inexactAllowWhileIdle]
/// — approximate delivery (typically within minutes), no special permission
/// needed, and still fires under Doze. `exactAllowWhileIdle` would need
/// `SCHEDULE_EXACT_ALARM`, which Play Store policy reserves for genuine
/// alarm-clock/calendar apps; a paper reminder is not that, and being a few
/// minutes late is a fair trade against asking for a permission this app
/// cannot justify. This was F09's own "decide at start" item.
final class FlutterLocalNotificationsPort implements LocalNotificationsPort {
  FlutterLocalNotificationsPort(this._plugin, this._channelName);

  final fln.FlutterLocalNotificationsPlugin _plugin;

  /// The Android channel's display name — Arabic, unconditionally. It is a
  /// label on Android's own per-app notification settings page, not
  /// something this app renders, so it is not worth threading the saved
  /// locale through the launch sequence for.
  final String _channelName;

  @override
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    await _plugin.initialize(
      settings: const fln.InitializationSettings(
        android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Notifications are asked for through the app's own permission
        // sheet (F09-T09) — right before the first reminder, never during
        // onboarding. `false` here stops the plugin firing its own iOS
        // prompt a second time on top of that.
        iOS: fln.DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          fln.AndroidNotificationChannel(
            reminderNotificationChannelId,
            _channelName,
          ),
        );
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    String? body,
  }) => _plugin.zonedSchedule(
    id: id,
    scheduledDate: tz.TZDateTime.from(at, tz.getLocation('Africa/Cairo')),
    notificationDetails: fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        reminderNotificationChannelId,
        _channelName,
      ),
    ),
    androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
    title: title,
    body: body,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<Set<int>> pendingIds() async {
    final requests = await _plugin.pendingNotificationRequests();
    return {for (final request in requests) request.id};
  }
}
