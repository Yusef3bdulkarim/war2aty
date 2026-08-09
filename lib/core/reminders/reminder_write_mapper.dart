import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/reminders_dao.dart';
import 'notification_id.dart';
import 'reminder_alert_status.dart';
import 'reminder_status.dart';

/// Builds the rows for a reminder and its alerts.
///
/// Used both to create a reminder and to fully replace one's alert set
/// (editing, F09-T08; snoozing, F09-T12) — those are the same write, just
/// re-saving the same [id]. [alertIds] must be exactly as long as
/// [alertTimes]; the repository generates one fresh id per alert.
ReminderWrite reminderWriteOf({
  required String id,
  String? documentId,
  required String title,
  String? description,
  required DateTime eventDate,
  int? eventMinuteOfDay,
  required bool isManual,
  required List<DateTime> alertTimes,
  required List<String> alertIds,
  required DateTime now,
  ReminderStatus status = ReminderStatus.pending,
}) {
  assert(
    alertIds.length == alertTimes.length,
    'one id per alert time: ${alertIds.length} != ${alertTimes.length}',
  );

  return ReminderWrite(
    reminder: RemindersCompanion.insert(
      id: id,
      documentId: documentId == null ? const Value.absent() : Value(documentId),
      title: title,
      description: description == null
          ? const Value.absent()
          : Value(description),
      eventDate: eventDate,
      eventMinuteOfDay: Value(eventMinuteOfDay),
      status: status,
      isManual: isManual,
      createdAt: now,
      updatedAt: now,
    ),
    alerts: [
      for (var i = 0; i < alertTimes.length; i++)
        ReminderAlertsCompanion.insert(
          id: alertIds[i],
          reminderId: id,
          scheduledAt: alertTimes[i],
          notificationId: notificationIdOf(alertIds[i]),
          status: ReminderAlertStatus.scheduled,
          createdAt: now,
        ),
    ],
  );
}
