import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notifications_port.dart';
import 'reminder_notification_response.dart';

/// The Android channel every reminder notification is posted under. One
/// channel is enough — reminders do not have sub-categories the user would
/// want to mute independently.
const String reminderNotificationChannelId = 'reminders';

/// The iOS category every reminder notification is posted under (F25-T02) —
/// on iOS a notification's buttons belong to its category, registered once
/// in [FlutterLocalNotificationsPort.initialize].
const String reminderNotificationCategoryId = 'reminder';

/// [LocalNotificationsPort] on top of `flutter_local_notifications` and the
/// `timezone` package (F09-T10) — the only file in the app allowed to drive
/// `flutter_local_notifications`, matching how `PermissionHandlerService` is
/// the only file that imports `permission_handler`. The two composition
/// roots import it only to hand it objects: `service_locator.dart` builds
/// the plugin, and `reminder_notification_background.dart` is the
/// background engine's entry point, typed by the plugin (F25-T05).
/// `core/time/cairo_day.dart`
/// also imports the `timezone` package on its own, narrower terms: it only
/// resolves `Africa/Cairo` for `cairoInstant` rather than driving the plugin.
/// This file still owns loading the IANA data itself ([initialize] below);
/// `cairoInstant` only ever reads what this already loaded at app start.
///
/// Android alarms are scheduled [fln.AndroidScheduleMode.inexactAllowWhileIdle]
/// — approximate delivery (typically within minutes), no special permission
/// needed, and still fires under Doze. `exactAllowWhileIdle` would need
/// `SCHEDULE_EXACT_ALARM`, which Play Store policy reserves for genuine
/// alarm-clock/calendar apps; a paper reminder is not that, and being a few
/// minutes late is a fair trade against asking for a permission this app
/// cannot justify. This was F09's own "decide at start" item.
final class FlutterLocalNotificationsPort implements LocalNotificationsPort {
  FlutterLocalNotificationsPort(
    this._plugin,
    this._channelName, {
    fln.DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) : _onBackgroundResponse = onBackgroundResponse;

  final fln.FlutterLocalNotificationsPlugin _plugin;

  /// Runs a pressed «تم» / «أجّل ساعة» in a background engine (F25-T05) —
  /// a top-level `@pragma('vm:entry-point')` function, registered with the
  /// platform in [initialize]. `null` for a port built inside that engine,
  /// which never calls [initialize].
  final fln.DidReceiveBackgroundNotificationResponseCallback?
  _onBackgroundResponse;

  /// The Android channel's display name — Arabic, unconditionally. It is a
  /// label on Android's own per-app notification settings page, not
  /// something this app renders, so it is not worth threading the saved
  /// locale through the launch sequence for.
  final String _channelName;

  @override
  Future<void> initialize({
    required ReminderNotificationActionLabels actionLabels,
    required void Function(ReminderNotificationResponse) onResponse,
  }) async {
    initializeReminderTimeZones();

    await _plugin.initialize(
      settings: fln.InitializationSettings(
        android: const fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Notifications are asked for through the app's own permission
        // sheet (F09-T09) — right before the first reminder, never during
        // onboarding. `false` here stops the plugin firing its own iOS
        // prompt a second time on top of that.
        iOS: fln.DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            fln.DarwinNotificationCategory(
              reminderNotificationCategoryId,
              actions: [
                for (final action in ReminderNotificationAction.values)
                  // No `foreground` option: pressing a button acts without
                  // opening the app (F25 locked decision #6).
                  fln.DarwinNotificationAction.plain(
                    action.id,
                    actionLabels.labelOf(action),
                  ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final parsed = reminderNotificationResponseFromPlugin(response);
        if (parsed != null) onResponse(parsed);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
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
    required String payload,
    required ReminderNotificationActionLabels actionLabels,
  }) => _plugin.zonedSchedule(
    id: id,
    scheduledDate: tz.TZDateTime.from(at, tz.getLocation('Africa/Cairo')),
    notificationDetails: fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        reminderNotificationChannelId,
        _channelName,
        // A note can run past one line; collapsed, Android would cut it off
        // with no way to read the rest.
        styleInformation: body == null
            ? null
            : fln.BigTextStyleInformation(body),
        actions: [
          for (final action in ReminderNotificationAction.values)
            // Defaults: no UI (handled in the background, F25-T05), and the
            // notification is dismissed once a button is pressed.
            fln.AndroidNotificationAction(
              action.id,
              actionLabels.labelOf(action),
            ),
        ],
      ),
      iOS: const fln.DarwinNotificationDetails(
        categoryIdentifier: reminderNotificationCategoryId,
      ),
    ),
    androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
    title: title,
    body: body,
    payload: payload,
  );

  @override
  Future<ReminderNotificationResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details == null || !details.didNotificationLaunchApp) return null;
    return response == null
        ? null
        : reminderNotificationResponseFromPlugin(response);
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<Set<int>> pendingIds() async {
    final requests = await _plugin.pendingNotificationRequests();
    return {for (final request in requests) request.id};
  }
}

/// Loads the IANA data and sets the plugin's local zone to Cairo — the part
/// of [FlutterLocalNotificationsPort.initialize] a background engine also
/// needs before it can schedule (F25-T05), without re-initializing the
/// plugin the app already set up.
void initializeReminderTimeZones() {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
}

/// Reads a plugin response into the app's own type — `null` when it is not
/// one of this app's reminder notifications (see
/// [reminderNotificationResponseOf]).
ReminderNotificationResponse? reminderNotificationResponseFromPlugin(
  fln.NotificationResponse response,
) => reminderNotificationResponseOf(
  payload: response.payload,
  actionId: response.actionId,
);
